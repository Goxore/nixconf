use crate::paths::Dirs;
use anyhow::{Context, Result};
use clap::ValueEnum;
use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::Write;
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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ValueEnum)]
#[serde(rename_all = "lowercase")]
#[value(rename_all = "lowercase")]
pub enum Reporting {
    Precise,
    Coarse,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Agent {
    pub pid: u32,
    pub kind: String,
    pub project: u8,
    pub activity: Activity,
    pub reporting: Reporting,
    pub updated: u128,
}

pub fn now_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

pub fn is_unread(agent: &Agent, active: u8, left_project_at: u128) -> bool {
    agent.activity == Activity::Idle
        && agent.project != active
        && agent.updated > left_project_at
}

pub fn alive(pid: u32) -> bool {
    Path::new(&format!("/proc/{pid}")).exists()
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

pub fn load(dirs: &Dirs, pid: u32) -> Option<Agent> {
    let raw = fs::read_to_string(path_for(dirs, pid)).ok()?;
    serde_json::from_str(&raw).ok()
}

pub fn record(dirs: &Dirs, agent: &Agent) -> Result<()> {
    let dir = dir(dirs);
    fs::create_dir_all(&dir).with_context(|| format!("cannot create {}", dir.display()))?;
    let path = path_for(dirs, agent.pid);
    let body = serde_json::to_string(agent).context("cannot serialize agent")?;
    let tmp = path.with_extension("json.tmp");
    {
        let mut f = File::create(&tmp).with_context(|| format!("cannot create {}", tmp.display()))?;
        f.write_all(body.as_bytes())?;
        f.sync_all()?;
    }
    fs::rename(&tmp, &path).with_context(|| format!("cannot replace {}", path.display()))?;
    Ok(())
}

pub fn forget(dirs: &Dirs, pid: u32) {
    let _ = fs::remove_file(path_for(dirs, pid));
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
}
