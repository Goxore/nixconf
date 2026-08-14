use crate::jj::{Jj, WorkingCopy};
use crate::root::Root;
use crate::ui;
use anyhow::{Result, bail};
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct WorkspaceState {
    pub jj_name: String,
    pub dir_name: String,
    pub dir: PathBuf,
    pub state: Result<WorkingCopy, String>,
}

pub fn states(root: &Root, jj: &Jj) -> Result<Vec<WorkspaceState>> {
    let mut out = Vec::new();

    for ws in jj.workspaces()? {
        let dir_name = root.dir_name_of(&ws.name);
        let dir = root.workspace_path(&dir_name);

        if !dir.join(".jj").exists() {
            continue;
        }

        let state = jj
            .working_copy_state(&dir)
            .map_err(|e| format!("{e:#}").lines().next().unwrap_or("").to_string());

        out.push(WorkspaceState {
            jj_name: ws.name,
            dir_name,
            dir,
            state,
        });
    }

    Ok(out)
}

pub fn refresh_all(root: &Root, jj: &Jj) -> Result<()> {
    let mut failures = Vec::new();

    for ws in jj.workspaces()? {
        let dir_name = root.dir_name_of(&ws.name);
        let dir = root.workspace_path(&dir_name);

        if !dir.join(".jj").exists() {
            continue;
        }

        match jj.update_stale(&dir) {
            Ok(true) => println!(
                "{} {}",
                ui::dim("  updated stale workspace"),
                ui::dim(&dir_name)
            ),
            Ok(false) => {}
            Err(e) => failures.push(format!("{dir_name}: {e:#}")),
        }
    }

    if !failures.is_empty() {
        bail!(
            "these workspaces still hold files from before the current history:\n         {}",
            failures.join("\n         ")
        );
    }

    Ok(())
}
