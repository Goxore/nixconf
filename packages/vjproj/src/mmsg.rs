use anyhow::{Context, Result, bail};
use serde::Deserialize;
use std::process::{Command, Stdio};

pub fn view(tag: u8) -> Result<()> {
    dispatch(&format!("view,{tag},0"))
}

pub fn tag_focused(tag: u8) -> Result<()> {
    dispatch(&format!("tag,{tag},0"))
}

pub fn toggle_view(tag: u8) -> Result<()> {
    dispatch(&format!("toggleview,{tag},0"))
}

pub fn toggle_tag(tag: u8) -> Result<()> {
    dispatch(&format!("toggletag,{tag},0"))
}

#[derive(Debug, Deserialize)]
struct TagInfo {
    index: u8,
    #[serde(default)]
    is_active: bool,
    #[serde(default)]
    client_count: u32,
}

#[derive(Debug, Deserialize)]
struct MonitorTags {
    #[serde(default)]
    tags: Vec<TagInfo>,
}

#[derive(Debug, Deserialize)]
struct AllTags {
    #[serde(default)]
    all_tags: Vec<MonitorTags>,
}

#[derive(Debug, Default)]
pub struct TagState {
    pub active: Option<u8>,
    pub occupied: Vec<u8>,
}

impl TagState {
    pub fn is_occupied(&self, tag: u8) -> bool {
        self.occupied.contains(&tag)
    }
}

pub fn tag_state() -> Result<TagState> {
    let out = run(&["get", "all-tags"])?;
    let parsed: AllTags =
        serde_json::from_str(&out).with_context(|| format!("cannot parse all-tags: {out}"))?;
    let mut state = TagState::default();
    for monitor in &parsed.all_tags {
        for tag in &monitor.tags {
            if tag.is_active && state.active.is_none() {
                state.active = Some(tag.index);
            }
            if tag.client_count > 0 && !state.occupied.contains(&tag.index) {
                state.occupied.push(tag.index);
            }
        }
    }
    Ok(state)
}

fn dispatch(arg: &str) -> Result<()> {
    let out = run(&["dispatch", arg])?;
    if out.contains("\"error\"") {
        bail!("mmsg dispatch {arg} returned: {}", out.trim());
    }
    Ok(())
}

fn run(args: &[&str]) -> Result<String> {
    let out = Command::new("mmsg")
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .context("cannot run mmsg (is mango running?)")?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        bail!("mmsg {} failed: {}", args.join(" "), err.trim());
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}
