use anyhow::{Context, Result, bail};
use std::path::Path;
use std::process::{Command, Stdio};

const FORMAT: &str =
    "#{pane_pid}\t#{pane_id}\t#{session_name}\t#{pane_width}\t#{pane_height}\t#{pane_current_path}";

pub const KINDS: [&str; 4] = ["claude-per", "claude-fish", "codex", "opencode"];

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize)]
pub struct Pane {
    pub pid: u32,
    pub id: String,
    pub session: String,
    pub width: u16,
    pub height: u16,
    pub dir: String,
}

impl Pane {
    pub fn number(&self) -> &str {
        self.id.trim_start_matches('%')
    }
}

pub fn parse_panes(raw: &str) -> Vec<Pane> {
    raw.lines().filter_map(parse_pane).collect()
}

fn parse_pane(line: &str) -> Option<Pane> {
    let mut fields = line.split('\t');
    Some(Pane {
        pid: fields.next()?.trim().parse().ok()?,
        id: fields.next()?.to_owned(),
        session: fields.next()?.to_owned(),
        width: fields.next()?.trim().parse().ok()?,
        height: fields.next()?.trim().parse().ok()?,
        dir: fields.next().unwrap_or_default().to_owned(),
    })
}

pub fn target(number: &str) -> Result<String> {
    if number.is_empty() || !number.chars().all(|c| c.is_ascii_digit()) {
        bail!("pane must be a number, got {number:?}");
    }
    Ok(format!("%{number}"))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Client {
    pub pid: u32,
    pub session: String,
}

pub fn parse_clients(raw: &str) -> Vec<Client> {
    raw.lines()
        .filter_map(|line| {
            let (pid, session) = line.split_once('\t')?;
            Some(Client {
                pid: pid.trim().parse().ok()?,
                session: session.to_owned(),
            })
        })
        .collect()
}

pub fn attached(clients: &[Client], session: &str) -> Option<u32> {
    clients
        .iter()
        .find(|client| client.session == session)
        .map(|client| client.pid)
}

pub fn clients() -> Vec<Client> {
    match run(&["list-clients", "-F", "#{client_pid}\t#{client_session}"]) {
        Ok(raw) => parse_clients(&raw),
        Err(_) => Vec::new(),
    }
}

pub fn panes() -> Result<Vec<Pane>> {
    match run(&["list-panes", "-a", "-F", FORMAT]) {
        Ok(raw) => Ok(parse_panes(&raw)),
        Err(_) => Ok(Vec::new()),
    }
}

pub const NARROWEST: u16 = 20;
pub const WIDEST: u16 = 400;
pub const SHORTEST: u16 = 5;
pub const TALLEST: u16 = 200;

pub fn fits(cols: u16, rows: u16) -> (u16, u16) {
    (cols.clamp(NARROWEST, WIDEST), rows.clamp(SHORTEST, TALLEST))
}

pub fn detach(tty: &str) -> Result<()> {
    run(&["detach-client", "-t", tty])?;
    Ok(())
}

pub fn close(pane: &str) -> Result<()> {
    run(&["kill-pane", "-t", pane])?;
    Ok(())
}

pub fn session_for(project: u8) -> String {
    format!("vjproj-{project}")
}

pub fn login_shell() -> String {
    std::env::var("VJPROJ_SHELL")
        .ok()
        .filter(|shell| !shell.trim().is_empty())
        .unwrap_or_else(|| "fish".to_owned())
}

fn only_pane(session: &str) -> Option<String> {
    run(&[
        "list-panes",
        "-t",
        &format!("={session}"),
        "-F",
        "#{pane_id}",
    ])
    .ok()?
    .lines()
    .next()
    .map(|line| line.trim().trim_start_matches('%').to_owned())
    .filter(|pane| !pane.is_empty())
}

pub fn end_session(project: u8) -> Result<()> {
    run(&["kill-session", "-t", &format!("={}", session_for(project))])?;
    Ok(())
}

pub fn shell(dir: &Path, project: u8) -> Result<(String, bool)> {
    crate::slots::require_project(project)?;
    let dir = crate::paths::home_dir(dir)?;

    let session = session_for(project);
    if let Some(pane) = only_pane(&session) {
        return Ok((pane, false));
    }

    let dir = dir.to_string_lossy().into_owned();
    let pinned = format!("VJAGENT_PROJECT={project}");
    let shell = login_shell();
    let raw = run(&[
        "new-session",
        "-d",
        "-P",
        "-F",
        "#{pane_id}",
        "-s",
        &session,
        "-c",
        &dir,
        "-e",
        &pinned,
        "--",
        &shell,
    ])?;
    Ok((raw.trim().trim_start_matches('%').to_owned(), true))
}

fn run(args: &[&str]) -> Result<String> {
    let out = Command::new("tmux")
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .context("cannot run tmux")?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        bail!("tmux {} failed: {}", args.join(" "), err.trim());
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}
