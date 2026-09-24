use anyhow::{Context, Result, bail};
use serde::Deserialize;
use std::io::{BufRead, BufReader};
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

#[derive(Debug, Clone, Deserialize)]
pub struct Window {
    pub id: u32,
    pub pid: u32,
    #[serde(default)]
    pub title: String,
    #[serde(default)]
    pub tags: Vec<u8>,
}

#[derive(Debug, Deserialize)]
struct AllClients {
    #[serde(default)]
    clients: Vec<Window>,
}

pub fn windows() -> Result<Vec<Window>> {
    parse_clients(&run(&["get", "all-clients"])?)
}

pub fn focus_window(id: u32) -> Result<()> {
    dispatch(&format!("focusid,{id}"))
}

pub fn retag_window(id: u32, tag: u8) -> Result<()> {
    dispatch_at(&format!("tagsilent,{tag},0"), id)
}

fn parse_clients(raw: &str) -> Result<Vec<Window>> {
    let parsed: AllClients =
        serde_json::from_str(raw).with_context(|| format!("cannot parse all-clients: {raw}"))?;
    Ok(parsed.clients)
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
    parse_tags(&run(&["get", "all-tags"])?)
}

pub fn watch_tags(mut on_change: impl FnMut(&TagState)) -> Result<()> {
    stream("all-tags", |line| {
        if let Ok(tags) = parse_tags(line) {
            on_change(&tags);
        }
    })
}

pub fn watch_windows(mut on_change: impl FnMut(Vec<Window>)) -> Result<()> {
    stream("all-clients", |line| {
        if let Ok(windows) = parse_clients(line) {
            on_change(windows);
        }
    })
}

fn stream(what: &str, mut on_line: impl FnMut(&str)) -> Result<()> {
    let mut child = Command::new("mmsg")
        .args(["watch", what])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .context("cannot run mmsg watch (is mango running?)")?;
    let out = child
        .stdout
        .take()
        .with_context(|| format!("mmsg watch {what} produced no output"))?;
    for line in BufReader::new(out).lines().map_while(Result::ok) {
        on_line(&line);
    }
    child
        .wait()
        .with_context(|| format!("cannot reap mmsg watch {what}"))?;
    Ok(())
}

pub fn parse_tags(raw: &str) -> Result<TagState> {
    let parsed: AllTags =
        serde_json::from_str(raw).with_context(|| format!("cannot parse all-tags: {raw}"))?;
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
    check(arg, run(&["dispatch", arg])?)
}

fn dispatch_at(arg: &str, window: u32) -> Result<()> {
    check(arg, run(&["dispatch", arg, &format!("client,{window}")])?)
}

fn check(arg: &str, out: String) -> Result<()> {
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
