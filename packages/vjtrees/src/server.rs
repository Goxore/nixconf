use crate::config::Server;
use crate::procs;
use crate::root::Root;
use crate::state;
use crate::ui;
use anyhow::{Context, Result, bail};
use std::fs;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr, TcpStream};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

const LOG_FILE: &str = ".vjtrees-server.log";
const HTTP_READY: Duration = Duration::from_secs(30);
const EXTRA_READY: Duration = Duration::from_secs(20);

const PROBE_HOSTS: [IpAddr; 2] = [
    IpAddr::V4(Ipv4Addr::LOCALHOST),
    IpAddr::V6(Ipv6Addr::LOCALHOST),
];

pub fn pid_file(root: &Root) -> PathBuf {
    root.state_dir().join("server.pid")
}

pub fn read_pid_file(root: &Root) -> Option<u32> {
    fs::read_to_string(pid_file(root)).ok()?.trim().parse().ok()
}

fn clear_pid_file(root: &Root) {
    let _ = fs::remove_file(pid_file(root));
}

pub fn can_connect(port: u16, timeout: Duration) -> bool {
    PROBE_HOSTS
        .iter()
        .any(|host| TcpStream::connect_timeout(&SocketAddr::new(*host, port), timeout).is_ok())
}

fn wait_for_port(port: u16, budget: Duration, pid: u32) -> bool {
    let deadline = Instant::now() + budget;

    while Instant::now() < deadline {
        if can_connect(port, Duration::from_millis(1000)) {
            return true;
        }
        if !procs::is_alive(pid) {
            return false;
        }
        std::thread::sleep(Duration::from_millis(100));
    }

    false
}

pub fn server_pids(root: &Root, config: &Server) -> Vec<u32> {
    let mut candidates = Vec::new();

    if let Some(pid) = state::read(root).server_pid {
        candidates.push(pid);
    }
    if let Some(pid) = read_pid_file(root) {
        candidates.push(pid);
    }
    for port in &config.ports {
        candidates.extend(procs::port_pids(*port));
    }

    let mut unique = Vec::new();
    for pid in candidates {
        if procs::is_alive(pid) && !unique.contains(&pid) {
            unique.push(pid);
        }
    }

    unique
}

pub fn stop(root: &Root, config: &Server) -> Result<Vec<u32>> {
    let pids = server_pids(root, config);

    if pids.is_empty() {
        state::update(root, |s| s.server_pid = None)?;
        clear_pid_file(root);
        return Ok(Vec::new());
    }

    let mut killed = Vec::new();
    for pid in &pids {
        for dead in procs::kill_group(*pid) {
            if !killed.contains(&dead) {
                killed.push(dead);
            }
        }
    }

    let stragglers: Vec<u32> = pids
        .iter()
        .copied()
        .filter(|p| procs::is_alive(*p))
        .flat_map(procs::descendants)
        .collect();

    for dead in procs::kill_pids(&stragglers) {
        if !killed.contains(&dead) {
            killed.push(dead);
        }
    }

    state::update(root, |s| s.server_pid = None)?;
    clear_pid_file(root);

    Ok(killed)
}

pub fn start(root: &Root, config: &Server, workspace_dir: &Path) -> Result<u32> {
    let log_path = workspace_dir.join(LOG_FILE);
    let pid_path = pid_file(root);

    fs::create_dir_all(root.state_dir())?;
    let _ = fs::remove_file(&pid_path);

    let program = shell_join(&config.command);
    let script = format!("echo $$ > \"$VJT_PIDFILE\"; exec {program}");

    let status = Command::new("bash")
        .arg("-c")
        .arg("setsid bash -c \"$VJT_SCRIPT\" > \"$VJT_LOG\" 2>&1 &")
        .current_dir(workspace_dir)
        .env("VJT_SCRIPT", &script)
        .env("VJT_PIDFILE", &pid_path)
        .env("VJT_LOG", &log_path)
        .status()
        .context("could not spawn the dev server")?;

    if !status.success() {
        bail!("could not start `{program}`");
    }

    let mut pid = None;
    for _ in 0..50 {
        std::thread::sleep(Duration::from_millis(100));
        if let Some(found) = read_pid_file(root)
            && procs::is_alive(found)
        {
            pid = Some(found);
            break;
        }
    }

    let Some(pid) = pid else {
        let log = tail(&log_path, 500);
        bail!("`{program}` did not start\n{log}");
    };

    if procs::pgid(pid) != Some(pid) {
        println!(
            "{}",
            ui::yellow("  warn: the server does not lead its own process group")
        );
    }

    state::update(root, |s| s.server_pid = Some(pid))?;

    let Some(first_port) = config.ports.first().copied() else {
        return Ok(pid);
    };

    if !wait_for_port(first_port, HTTP_READY, pid) {
        println!(
            "{} {}",
            ui::yellow("  warn:"),
            if procs::is_alive(pid) {
                format!("nothing is listening on {first_port} yet")
            } else {
                format!("the server exited before binding {first_port}")
            }
        );
        let log = tail(&log_path, 400);
        if !log.is_empty() {
            println!("{}", ui::dim(&log));
        }
        return Ok(pid);
    }

    let wait_extra = match &config.wait_if_present {
        Some(marker) => workspace_dir.join(marker).exists(),
        None => true,
    };

    if wait_extra {
        for port in &config.wait_ports {
            if !wait_for_port(*port, EXTRA_READY, pid) {
                println!("{} nothing came up on {port}", ui::yellow("  warn:"));
            }
        }
    }

    println!(
        "{} {}",
        ui::dim(&format!("  server started (pid {pid})")),
        ui::cyan(&format!("http://localhost:{first_port}"))
    );

    Ok(pid)
}

fn tail(path: &Path, bytes: usize) -> String {
    let Ok(text) = fs::read_to_string(path) else {
        return String::new();
    };
    let start = text.len().saturating_sub(bytes);
    text[start..].trim().to_string()
}

pub fn shell_join(args: &[String]) -> String {
    args.iter()
        .map(|arg| {
            if arg
                .chars()
                .all(|c| c.is_alphanumeric() || "-_./=:".contains(c))
            {
                arg.clone()
            } else {
                format!("'{}'", arg.replace('\'', r"'\''"))
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}
