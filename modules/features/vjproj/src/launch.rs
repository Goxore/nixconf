use crate::{agents, mmsg, slots, tmux};
use anyhow::{Context, Result, bail};
use std::collections::HashSet;
use std::path::Path;
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

const SETTLE: Duration = Duration::from_millis(120);

const APPEAR_TRIES: usize = 40;

pub fn terminal() -> String {
    std::env::var("VJPROJ_TERMINAL").unwrap_or_else(|_| "kitty".into())
}

pub fn agent(kind: &str, dir: &Path, project: u8) -> Result<u32> {
    if !tmux::KINDS.contains(&kind) {
        bail!("unknown agent {kind:?}");
    }
    let dir = crate::paths::home_dir(dir)?;
    slots::require_project(project)?;

    let before = window_ids();

    let mut child = Command::new(terminal())
        .arg("-e")
        .arg(kind)
        .current_dir(dir)
        .env("VJAGENT_PROJECT", project.to_string())
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .with_context(|| format!("cannot run {}", terminal()))?;

    let pid = child.id();
    thread::spawn(move || child.wait());

    if let Some(window) = appeared(pid, &before) {
        let tag = slots::real_tag(project, slots::HOME_SLOT)?;
        mmsg::retag_window(window, tag)?;
    }
    Ok(pid)
}

fn window_ids() -> HashSet<u32> {
    mmsg::windows()
        .unwrap_or_default()
        .iter()
        .map(|window| window.id)
        .collect()
}

fn appeared(child: u32, before: &HashSet<u32>) -> Option<u32> {
    for _ in 0..APPEAR_TRIES {
        thread::sleep(SETTLE);
        let windows = mmsg::windows().unwrap_or_default();

        if let Some(window) = windows.iter().find(|window| window.pid == child) {
            return Some(window.id);
        }
        if let Some(window) = windows
            .iter()
            .find(|window| agents::ancestry(window.pid).contains(&child))
        {
            return Some(window.id);
        }
        if let Some(window) = windows.iter().find(|window| !before.contains(&window.id)) {
            return Some(window.id);
        }
    }
    None
}
