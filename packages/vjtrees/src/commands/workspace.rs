use anyhow::{Context, Result, bail};
use std::fs;
use std::path::Path;
use std::process::Command;
use vjtrees::config::Setup;
use vjtrees::editor;
use vjtrees::guard::{Mutation, guarded};
use vjtrees::jj::Jj;
use vjtrees::procs;
use vjtrees::root::Root;
use vjtrees::server;
use vjtrees::state;
use vjtrees::ui::{self, Choice};

const DEV_COMMS: &[&str] = &["bun", "node", "vite", "esbuild", "cargo", "python3"];

fn choose(root: &Root, jj: &Jj, prompt: &str, skip_trunk: bool) -> Result<Option<String>> {
    let workspaces = jj.workspaces()?;
    let current = state::read(root).current_workspace;

    let choices: Vec<Choice<String>> = workspaces
        .iter()
        .filter(|w| !skip_trunk || w.name != root.trunk_workspace())
        .map(|w| {
            let dir_name = root.dir_name_of(&w.name);
            let marker = if current.as_deref() == Some(dir_name.as_str()) {
                ui::cyan(">")
            } else {
                " ".into()
            };
            let description = if w.description.is_empty() {
                ui::dim("(no description set)")
            } else {
                w.description.clone()
            };
            Choice::new(
                format!("{marker} {dir_name:<24} {description}"),
                dir_name.clone(),
            )
        })
        .collect();

    if choices.is_empty() {
        bail!("no workspaces to choose from");
    }

    Ok(ui::select(prompt, choices)?.map(|c| c.value))
}

fn resolve_name(
    root: &Root,
    jj: &Jj,
    given: Option<String>,
    prompt: &str,
    skip_trunk: bool,
) -> Result<String> {
    if let Some(name) = given {
        return Ok(name);
    }

    match choose(root, jj, prompt, skip_trunk)? {
        Some(name) => Ok(name),
        None => {
            println!("{}", ui::dim("  nothing selected"));
            std::process::exit(0);
        }
    }
}

fn needs_setup(dir: &Path, setup: &Setup) -> bool {
    let Some(marker) = &setup.when_missing else {
        return false;
    };

    let marker_path = dir.join(marker);
    if !marker_path.exists() {
        return true;
    }

    let Some(newer) = &setup.when_newer else {
        return false;
    };

    let source = dir.join(newer);
    let (Ok(source_meta), Ok(marker_meta)) = (fs::metadata(&source), fs::metadata(&marker_path))
    else {
        return false;
    };

    match (source_meta.modified(), marker_meta.modified()) {
        (Ok(a), Ok(b)) => a > b,
        _ => false,
    }
}

fn run_setup(dir: &Path, setup: &Setup) -> Result<()> {
    if !needs_setup(dir, setup) {
        return Ok(());
    }

    let Some((program, args)) = setup.command.split_first() else {
        return Ok(());
    };

    println!("{} {}", ui::dim("  setup:"), setup.command.join(" "));

    let status = Command::new(program)
        .args(args)
        .current_dir(dir)
        .status()
        .with_context(|| format!("could not run `{program}`"))?;

    if !status.success() {
        bail!("`{}` failed in {}", setup.command.join(" "), dir.display());
    }

    Ok(())
}

pub fn open(root: &Root, name: Option<String>, no_open: bool) -> Result<()> {
    let jj = Jj::new(&root.trunk);
    let name = resolve_name(root, &jj, name, "Which workspace?", false)?;
    let dir = root.workspace_path(&name);

    if !dir.join(".jj").exists() {
        bail!("{} is not a jj workspace", dir.display());
    }

    println!();
    println!("{} {}", ui::bold("  opening"), ui::dim(&name));
    println!();

    if let Some(config) = &root.config.server {
        server::stop(root, config)?;
    }

    if jj.update_stale(&dir)? {
        println!("{}", ui::dim("  updated stale workspace"));
    }

    if let Some(setup) = &root.config.setup {
        run_setup(&dir, setup)?;
    }

    if let Some(config) = &root.config.server {
        server::start(root, config, &dir)?;
    }

    state::update(root, |s| s.current_workspace = Some(name.clone()))?;

    if no_open {
        println!(
            "{}",
            ui::green("  ready (--no-open: not launching the editor)")
        );
        return Ok(());
    }

    let launch = editor::plan(root, &root.config.open, &dir)?;
    editor::launch(&launch)
}

pub fn new(root: &Root, name: String, no_open: bool) -> Result<()> {
    if !name
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
        || name.is_empty()
    {
        bail!("workspace name must be alphanumeric, - or _");
    }

    let dir = root.workspace_path(&name);
    if dir.exists() {
        bail!("{} already exists", dir.display());
    }

    let jj = Jj::new(&root.trunk);

    let mutation = Mutation::new("new", &format!("Create workspace {name}"))
        .effect(format!("add jj workspace {name}"))
        .effect(format!("create {}", dir.display()));

    guarded(root, &jj, mutation, |_| jj.workspace_add(&dir, &name, None))?;

    open(root, Some(name), no_open)
}

pub fn delete(root: &Root, name: Option<String>) -> Result<()> {
    let jj = Jj::new(&root.trunk);
    let name = resolve_name(root, &jj, name, "Which workspace should be deleted?", true)?;

    if name == root.trunk_dir_name() {
        bail!("cannot delete the trunk workspace");
    }

    let dir = root.workspace_path(&name);
    if !dir.exists() {
        bail!("{} does not exist", dir.display());
    }

    if state::read(root).current_workspace.as_deref() == Some(name.as_str()) {
        bail!("{name} is the current workspace — switch away first with: vjtrees open");
    }

    let working_copy = jj.working_copy_state(&dir);

    let mut mutation = Mutation::new("delete", &format!("Delete workspace {name}"))
        .effect(format!("forget jj workspace {name}"))
        .effect(format!("recursively remove {}", dir.display()))
        .effect(ui::dim(
            "jj-tracked content survives in the repo; anything untracked or ignored does not",
        ))
        .irreversible(&name);

    match working_copy {
        Ok(vjtrees::jj::WorkingCopy::Modified) => {
            mutation = mutation.effect(ui::yellow(
                "its working-copy change is not empty — check it is described before deleting",
            ));
        }
        Err(e) => {
            mutation = mutation.effect(ui::red(&format!(
                "jj cannot read this working copy ({e:#}) — deleting blind",
            )));
        }
        Ok(_) => {}
    }

    guarded(root, &jj, mutation, |_| {
        jj.workspace_forget(&name)?;
        fs::remove_dir_all(&dir).with_context(|| format!("cannot remove {}", dir.display()))?;
        println!("{} {name}", ui::green("  deleted"));
        Ok(())
    })
}

pub fn stop(root: &Root) -> Result<()> {
    println!();
    println!(
        "{} {}",
        ui::bold("  stop"),
        ui::dim(&root.root.display().to_string())
    );
    println!();

    let mut spared = procs::self_chain();
    spared.extend(procs::descendants(std::process::id()));

    let mut stopped = false;

    if let Some(config) = &root.config.server {
        let killed: Vec<u32> = server::stop(root, config)?
            .into_iter()
            .filter(|p| !spared.contains(p))
            .collect();

        if !killed.is_empty() {
            stopped = true;
            println!("{} {killed:?}", ui::green("  server stopped"));
        }
    }

    let strays = procs::strays(&root.root, DEV_COMMS, &spared);
    if !strays.is_empty() {
        for stray in &strays {
            let line: String = stray.cmdline.chars().take(60).collect();
            println!(
                "{} {line} {}",
                ui::yellow("  stray"),
                ui::dim(&format!("(pid {})", stray.pid))
            );
        }

        let pids: Vec<u32> = strays
            .iter()
            .flat_map(|p| procs::descendants(p.pid))
            .collect();
        procs::kill_pids(&pids);
        stopped = true;
    }

    println!();
    println!(
        "{}",
        if stopped {
            ui::green("  all stopped")
        } else {
            ui::dim("  nothing was running")
        }
    );
    println!();

    Ok(())
}
