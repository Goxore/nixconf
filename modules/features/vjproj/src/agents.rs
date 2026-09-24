use crate::paths::Dirs;
use crate::status;
use anyhow::{Context, Result};
use clap::ValueEnum;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ValueEnum)]
#[serde(rename_all = "lowercase")]
#[value(rename_all = "lowercase")]
pub enum Activity {
    Working,
    Blocked,
    Idle,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Agent {
    pub pid: u32,
    pub kind: String,
    pub project: u8,
    pub activity: Activity,
    pub updated: u128,
    #[serde(default)]
    pub notice: String,
}

const ANCESTRY_DEPTH: usize = 12;

const END_TTL_MS: u128 = 30_000;

pub fn now_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

const RESTING_NOTICES: [&str; 2] = ["idle_prompt", "agent_completed"];

pub fn idle_nag(message: &str) -> bool {
    message.to_lowercase().contains("waiting for your input")
}

#[derive(Debug, Clone, Copy, Default)]
pub struct Notice<'a> {
    pub kind: Option<&'a str>,
    pub message: Option<&'a str>,
}

impl Notice<'_> {
    fn waiting_for_you(&self) -> bool {
        match self.kind {
            Some(kind) => RESTING_NOTICES.contains(&kind),
            None => self.message.is_some_and(idle_nag),
        }
    }
}

pub fn notified(known: Option<&Agent>, notice: Notice) -> Option<Activity> {
    if known.is_some_and(|agent| agent.activity == Activity::Idle) {
        return None;
    }
    Some(if notice.waiting_for_you() {
        Activity::Idle
    } else {
        Activity::Blocked
    })
}

const NOTICE_LIMIT: usize = 200;

pub fn gist(message: &str) -> String {
    let text = message.trim();
    match text.char_indices().nth(NOTICE_LIMIT) {
        Some((at, _)) => text[..at].to_string(),
        None => text.to_string(),
    }
}

pub fn carried(known: Option<&Agent>, activity: Activity, message: Option<&str>) -> String {
    match (activity, message) {
        (Activity::Working, _) => String::new(),
        (_, Some(message)) => gist(message),
        (_, None) => known.map(|agent| agent.notice.clone()).unwrap_or_default(),
    }
}

pub const BLOCKED_BUSY_TICKS: u64 = 50;

pub const BLOCKED_BUSY_WINDOW_MS: u128 = 1_000;

#[derive(Debug, Clone, Copy)]
pub struct Burst {
    opened: u128,
    base: u64,
}

impl Burst {
    pub fn opened(now: u128, ticks: u64) -> Self {
        Self {
            opened: now,
            base: ticks,
        }
    }

    pub fn sustained(&mut self, now: u128, ticks: u64) -> bool {
        if ticks.saturating_sub(self.base) >= BLOCKED_BUSY_TICKS {
            return true;
        }
        if now.saturating_sub(self.opened) >= BLOCKED_BUSY_WINDOW_MS {
            *self = Self::opened(now, ticks);
        }
        false
    }
}

pub fn unblocked_by_work(agent: &Agent, busy: bool) -> Activity {
    if agent.activity == Activity::Blocked && busy {
        Activity::Working
    } else {
        agent.activity
    }
}

pub const BLOCK_GRACE_MS: u128 = 8_000;

pub fn needs_attention(
    agent: &Agent,
    present: Option<u8>,
    left_project_at: u128,
    now: u128,
) -> bool {
    match agent.activity {
        Activity::Working => false,
        Activity::Blocked => now.saturating_sub(agent.updated) >= BLOCK_GRACE_MS,
        Activity::Idle => present != Some(agent.project) && agent.updated > left_project_at,
    }
}

pub fn alive(pid: u32) -> bool {
    Path::new(&format!("/proc/{pid}")).exists()
}

pub fn cwd(pid: u32) -> Option<String> {
    fs::read_link(format!("/proc/{pid}/cwd"))
        .ok()
        .map(|path| path.to_string_lossy().into_owned())
}

pub fn ancestry(pid: u32) -> Vec<u32> {
    let mut chain = Vec::new();
    let mut at = pid;
    while chain.len() < ANCESTRY_DEPTH {
        match parent_of(at) {
            Some(parent) if parent > 1 => {
                chain.push(parent);
                at = parent;
            }
            _ => break,
        }
    }
    chain
}

fn parent_of(pid: u32) -> Option<u32> {
    parse_parent(&fs::read_to_string(format!("/proc/{pid}/stat")).ok()?)
}

pub fn parse_parent(stat: &str) -> Option<u32> {
    let tail = stat.rsplit_once(')')?.1;
    tail.split_whitespace().nth(1)?.parse().ok()
}

pub fn cpu_ticks(pid: u32) -> Option<u64> {
    let raw = fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
    let tail = raw.rsplit_once(')')?.1;
    let mut fields = tail.split_whitespace();
    let utime: u64 = fields.nth(11)?.parse().ok()?;
    let stime: u64 = fields.next()?.parse().ok()?;
    Some(utime + stime)
}

fn dir(dirs: &Dirs) -> PathBuf {
    dirs.agents()
}

fn path_for(dirs: &Dirs, pid: u32) -> PathBuf {
    dir(dirs).join(format!("{pid}.json"))
}

fn ended_path(dirs: &Dirs, pid: u32) -> PathBuf {
    dir(dirs).join(format!("{pid}.ended"))
}

pub fn load(dirs: &Dirs, pid: u32) -> Option<Agent> {
    let raw = fs::read_to_string(path_for(dirs, pid)).ok()?;
    serde_json::from_str(&raw).ok()
}

pub fn record(dirs: &Dirs, agent: &Agent) -> Result<()> {
    let dir = dir(dirs);
    fs::create_dir_all(&dir).with_context(|| format!("cannot create {}", dir.display()))?;
    let path = path_for(dirs, agent.pid);
    let body = serde_json::to_string(agent).context("cannot serialize agent")?;
    vjcommon::atomic::write(&path, body.as_bytes())
}

pub fn forget(dirs: &Dirs, pid: u32) {
    let _ = fs::remove_file(path_for(dirs, pid));
    let _ = fs::remove_file(ended_path(dirs, pid));
    status::forget(dirs, pid);
}

pub fn end(dirs: &Dirs, pid: u32) {
    let _ = vjcommon::atomic::write(&ended_path(dirs, pid), now_ms().to_string().as_bytes());
    if alive(pid) {
        return;
    }
    let _ = fs::remove_file(path_for(dirs, pid));
    status::forget(dirs, pid);
}

pub fn recently_ended(dirs: &Dirs, pid: u32) -> bool {
    fs::read_to_string(ended_path(dirs, pid))
        .ok()
        .and_then(|raw| raw.trim().parse::<u128>().ok())
        .is_some_and(|at| now_ms().saturating_sub(at) < END_TTL_MS)
}

pub fn gone(dirs: &Dirs, pid: u32) -> bool {
    recently_ended(dirs, pid) && !alive(pid)
}

pub fn cleared(reason: Option<&str>) -> bool {
    reason == Some("clear")
}

pub fn pinned(raw: Option<&str>) -> Option<u8> {
    raw?.trim()
        .parse()
        .ok()
        .filter(|&project| crate::slots::valid_project(project))
}

fn sweep_ended(dirs: &Dirs) {
    let Ok(entries) = fs::read_dir(dir(dirs)) else {
        return;
    };
    for path in entries
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.extension().is_some_and(|ext| ext == "ended"))
    {
        let live = fs::read_to_string(&path)
            .ok()
            .and_then(|raw| raw.trim().parse::<u128>().ok())
            .is_some_and(|at| now_ms().saturating_sub(at) < END_TTL_MS);
        if !live {
            let _ = fs::remove_file(&path);
        }
    }
}

pub fn load_all(dirs: &Dirs) -> Vec<Agent> {
    let Ok(entries) = fs::read_dir(dir(dirs)) else {
        return Vec::new();
    };
    let mut found: Vec<Agent> = entries
        .flatten()
        .filter(|e| e.path().extension().is_some_and(|ext| ext == "json"))
        .filter_map(|e| fs::read_to_string(e.path()).ok())
        .filter_map(|raw| serde_json::from_str(&raw).ok())
        .collect();
    found.sort_by_key(|a: &Agent| (a.project, a.pid));
    found
}

pub fn reap(dirs: &Dirs, agents: &mut Vec<Agent>) {
    agents.retain(|agent| {
        if alive(agent.pid) {
            return true;
        }
        forget(dirs, agent.pid);
        false
    });
    sweep_ended(dirs);
}
