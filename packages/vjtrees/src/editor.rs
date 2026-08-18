use crate::config::{Open, substitute};
use crate::root::Root;
use crate::ui;
use anyhow::{Context, Result, bail};
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Launch {
    pub program: String,
    pub args: Vec<String>,
    pub cwd: PathBuf,
}

pub fn plan(root: &Root, open: &Open, workspace_dir: &Path) -> Result<Launch> {
    let name = workspace_dir
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();

    let entry = open.entry.clone().unwrap_or_default();

    let values: Vec<(&str, &str)> = vec![
        ("root", root.root.to_str().unwrap_or_default()),
        ("workspace", workspace_dir.to_str().unwrap_or_default()),
        ("name", &name),
        ("entry", &entry),
    ];

    let rendered: Vec<String> = open
        .command
        .iter()
        .map(|arg| substitute(arg, &values))
        .collect();

    let Some((program, args)) = rendered.split_first() else {
        bail!("[open] command is empty");
    };

    let cwd = match &open.cwd {
        Some(relative) => {
            let resolved = workspace_dir.join(substitute(relative, &values));
            if resolved.is_dir() {
                resolved
            } else {
                workspace_dir.to_path_buf()
            }
        }
        None => workspace_dir.to_path_buf(),
    };

    Ok(Launch {
        program: program.clone(),
        args: args.to_vec(),
        cwd,
    })
}

pub fn launch(launch: &Launch) -> Result<()> {
    println!(
        "{} {}",
        ui::dim("  launching"),
        ui::cyan(&launch.cwd.display().to_string())
    );

    let status = Command::new(&launch.program)
        .args(&launch.args)
        .current_dir(&launch.cwd)
        .env("PWD", &launch.cwd)
        .status()
        .with_context(|| format!("could not run `{}`", launch.program))?;

    if !status.success()
        && let Some(code) = status.code()
        && code != 0
    {
        eprintln!("{} exited with {code}", launch.program);
    }

    Ok(())
}
