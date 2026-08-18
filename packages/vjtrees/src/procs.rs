use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone)]
pub struct Proc {
    pub pid: u32,
    pub comm: String,
    pub cmdline: String,
    pub cwd: Option<PathBuf>,
}

pub fn is_alive(pid: u32) -> bool {
    Path::new(&format!("/proc/{pid}")).exists()
}

fn all_pids() -> Vec<u32> {
    let Ok(entries) = fs::read_dir("/proc") else {
        return Vec::new();
    };

    entries
        .flatten()
        .filter_map(|e| e.file_name().to_string_lossy().parse::<u32>().ok())
        .collect()
}

fn stat_field(pid: u32, index: usize) -> Option<u32> {
    let stat = fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
    let tail = &stat[stat.rfind(')')? + 1..];
    tail.split_whitespace().nth(index)?.parse().ok()
}

pub fn ppid(pid: u32) -> Option<u32> {
    stat_field(pid, 1)
}

pub fn pgid(pid: u32) -> Option<u32> {
    stat_field(pid, 2)
}

pub fn read_proc(pid: u32) -> Option<Proc> {
    let comm = fs::read_to_string(format!("/proc/{pid}/comm"))
        .ok()?
        .trim()
        .to_string();

    let cmdline = fs::read_to_string(format!("/proc/{pid}/cmdline"))
        .map(|raw| {
            raw.split('\0')
                .filter(|s| !s.is_empty())
                .collect::<Vec<_>>()
                .join(" ")
        })
        .unwrap_or_default();

    let cwd = fs::read_link(format!("/proc/{pid}/cwd")).ok();

    Some(Proc {
        pid,
        comm: comm.clone(),
        cmdline: if cmdline.is_empty() { comm } else { cmdline },
        cwd,
    })
}

pub fn self_chain() -> Vec<u32> {
    let mut chain = Vec::new();
    let mut pid = Some(std::process::id());

    while let Some(current) = pid {
        if current <= 1 || chain.contains(&current) {
            break;
        }
        chain.push(current);
        pid = ppid(current);
    }

    chain
}

pub fn descendants(root: u32) -> Vec<u32> {
    let pairs: Vec<(u32, u32)> = all_pids()
        .into_iter()
        .filter_map(|pid| ppid(pid).map(|parent| (parent, pid)))
        .collect();

    let mut found = Vec::new();
    let mut queue = vec![root];

    while let Some(pid) = queue.pop() {
        if found.contains(&pid) {
            continue;
        }
        found.push(pid);
        queue.extend(pairs.iter().filter(|(p, _)| *p == pid).map(|(_, c)| *c));
    }

    found
}

fn signal(pid: u32, sig: &str) {
    let _ = Command::new("kill")
        .args([&format!("-{sig}"), &pid.to_string()])
        .output();
}

fn signal_group(pgid: u32, sig: &str) {
    let _ = Command::new("kill")
        .args([&format!("-{sig}"), &format!("-{pgid}")])
        .output();
}

fn wait_for_exit(pids: &[u32], tries: u32) -> bool {
    for _ in 0..tries {
        if !pids.iter().any(|p| is_alive(*p)) {
            return true;
        }
        std::thread::sleep(std::time::Duration::from_millis(100));
    }
    !pids.iter().any(|p| is_alive(*p))
}

pub fn kill_pids(pids: &[u32]) -> Vec<u32> {
    let alive: Vec<u32> = pids.iter().copied().filter(|p| is_alive(*p)).collect();
    if alive.is_empty() {
        return Vec::new();
    }

    for pid in alive.iter().rev() {
        signal(*pid, "TERM");
    }

    if !wait_for_exit(&alive, 30) {
        for pid in alive.iter().filter(|p| is_alive(**p)) {
            signal(*pid, "KILL");
        }
    }

    alive
}

pub fn kill_group(pid: u32) -> Vec<u32> {
    if !is_alive(pid) {
        return Vec::new();
    }

    let group = pgid(pid);
    let own_group = pgid(std::process::id());

    if group == Some(pid) && group != own_group {
        let leader = pid;
        let members: Vec<u32> = all_pids()
            .into_iter()
            .filter(|p| pgid(*p) == Some(leader))
            .collect();

        signal_group(leader, "TERM");

        if !wait_for_exit(&members, 30) {
            signal_group(leader, "KILL");
        }

        return members;
    }

    kill_pids(&descendants(pid))
}

pub fn port_pids(port: u16) -> Vec<u32> {
    let Ok(output) = Command::new("ss")
        .args(["-ltnpH", &format!("sport = :{port}")])
        .output()
    else {
        return Vec::new();
    };

    let text = String::from_utf8_lossy(&output.stdout);
    let mut pids = Vec::new();

    for chunk in text.split("pid=").skip(1) {
        let digits: String = chunk.chars().take_while(char::is_ascii_digit).collect();
        if let Ok(pid) = digits.parse::<u32>()
            && !pids.contains(&pid)
        {
            pids.push(pid);
        }
    }

    pids
}

pub fn strays(root: &Path, dev_comms: &[&str], spared: &[u32]) -> Vec<Proc> {
    all_pids()
        .into_iter()
        .filter(|pid| !spared.contains(pid))
        .filter_map(read_proc)
        .filter(|proc| dev_comms.contains(&proc.comm.as_str()))
        .filter(|proc| proc.cwd.as_ref().is_some_and(|cwd| cwd.starts_with(root)))
        .collect()
}
