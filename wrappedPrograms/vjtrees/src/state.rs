use crate::root::Root;
use anyhow::{Context, Result};
use std::fs;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct State {
    pub current_workspace: Option<String>,
    pub server_pid: Option<u32>,
}

fn parse(text: &str) -> State {
    let mut state = State::default();

    for line in text.lines() {
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        let value = value.trim();
        match key.trim() {
            "current-workspace" if !value.is_empty() => {
                state.current_workspace = Some(value.to_string());
            }
            "server-pid" => state.server_pid = value.parse().ok(),
            _ => {}
        }
    }

    state
}

pub fn read(root: &Root) -> State {
    fs::read_to_string(root.state_path())
        .map(|text| parse(&text))
        .unwrap_or_default()
}

pub fn write(root: &Root, state: &State) -> Result<()> {
    let dir = root.state_dir();
    fs::create_dir_all(&dir).with_context(|| format!("cannot create {}", dir.display()))?;

    let mut text = String::new();
    if let Some(name) = &state.current_workspace {
        text.push_str(&format!("current-workspace = {name}\n"));
    }
    if let Some(pid) = state.server_pid {
        text.push_str(&format!("server-pid = {pid}\n"));
    }

    fs::write(root.state_path(), text)
        .with_context(|| format!("cannot write {}", root.state_path().display()))
}

pub fn update(root: &Root, change: impl FnOnce(&mut State)) -> Result<State> {
    let mut state = read(root);
    change(&mut state);
    write(root, &state)?;
    Ok(state)
}
