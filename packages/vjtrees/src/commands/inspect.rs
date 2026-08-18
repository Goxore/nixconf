use anyhow::Result;
use std::process::Command;
use vjtrees::jj::{Jj, WorkingCopy, quote_workspace};
use vjtrees::procs;
use vjtrees::root::Root;
use vjtrees::stale;
use vjtrees::state;
use vjtrees::target::{NoTarget, pick_target};
use vjtrees::ui;

const MIN_JJ: (u32, u32, u32) = (0, 30, 0);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Level {
    Ok,
    Warn,
    Fail,
}

#[derive(Debug, Clone)]
struct Check {
    level: Level,
    name: String,
    detail: String,
    fix: Option<String>,
}

impl Check {
    fn ok(name: &str, detail: impl Into<String>) -> Self {
        Self {
            level: Level::Ok,
            name: name.to_string(),
            detail: detail.into(),
            fix: None,
        }
    }

    fn warn(name: &str, detail: impl Into<String>) -> Self {
        Self {
            level: Level::Warn,
            name: name.to_string(),
            detail: detail.into(),
            fix: None,
        }
    }

    fn fail(name: &str, detail: impl Into<String>) -> Self {
        Self {
            level: Level::Fail,
            name: name.to_string(),
            detail: detail.into(),
            fix: None,
        }
    }

    fn fix(mut self, fix: impl Into<String>) -> Self {
        self.fix = Some(fix.into());
        self
    }
}

pub fn list(root: &Root) -> Result<()> {
    let jj = Jj::new(&root.trunk);
    let workspaces = jj.workspaces()?;
    let current = state::read(root).current_workspace;

    println!();
    println!(
        "{} {}",
        ui::bold("  workspaces"),
        ui::dim(&root.root.display().to_string())
    );
    println!();

    for ws in &workspaces {
        let dir_name = root.dir_name_of(&ws.name);
        let is_trunk = ws.name == root.trunk_workspace();
        let marker = if current.as_deref() == Some(dir_name.as_str()) {
            ui::cyan(">")
        } else {
            " ".to_string()
        };

        let tag = if is_trunk {
            ui::magenta(" trunk")
        } else {
            String::new()
        };

        let divergent = if ws.divergent {
            ui::red("  DIVERGENT")
        } else {
            String::new()
        };

        let description = if ws.description.is_empty() {
            ui::dim("(no description set)")
        } else {
            ws.description.clone()
        };

        println!("  {marker} {:<24}{tag}{divergent}  {description}", dir_name);
    }

    println!();
    Ok(())
}

pub fn status(root: &Root) -> Result<()> {
    let jj = Jj::new(&root.trunk);
    let st = state::read(root);

    println!();
    println!(
        "{} {}",
        ui::bold("  status"),
        ui::dim(&root.root.display().to_string())
    );
    println!();
    println!(
        "    current    {}",
        st.current_workspace.clone().unwrap_or_else(|| "-".into())
    );

    for ws in stale::states(root, &jj)? {
        let rendered = match &ws.state {
            Ok(WorkingCopy::Clean) => ui::dim("clean"),
            Ok(WorkingCopy::Modified) => ui::yellow("modified"),
            Ok(WorkingCopy::Stale) => ui::red("stale"),
            Err(e) => ui::red(&format!("unreadable: {e}")),
        };
        println!("    {:<20} {rendered}", ws.dir_name);
    }

    if let Some(server) = &root.config.server {
        println!();
        for port in &server.ports {
            let holders = procs::port_pids(*port);
            let rendered = if holders.is_empty() {
                ui::dim("free")
            } else {
                ui::green(&format!("held by {holders:?}"))
            };
            println!("    port {port:<15} {rendered}");
        }
    }

    println!();
    Ok(())
}

pub fn doctor(root: &Root) -> Result<bool> {
    let jj = Jj::new(&root.trunk);

    println!();
    println!(
        "{} {}",
        ui::bold("  doctor"),
        ui::dim(&root.root.display().to_string())
    );
    println!();

    let sections: Vec<(&str, Vec<Check>)> = vec![
        ("tools", check_tools(&jj)),
        ("repository", check_repo(root, &jj)),
        ("history", check_history(root, &jj)),
        ("runtime", check_runtime(root)),
    ];

    let mut failed = 0;
    let mut warned = 0;

    for (name, checks) in &sections {
        println!("  {}", ui::heading(name));
        for check in checks {
            let mark = match check.level {
                Level::Ok => ui::green("ok  "),
                Level::Warn => ui::yellow("warn"),
                Level::Fail => ui::red("FAIL"),
            };
            println!("    {mark}  {:<20} {}", check.name, ui::dim(&check.detail));
            if let Some(fix) = &check.fix {
                println!("            {} {}", ui::dim("fix:"), ui::cyan(fix));
            }
            match check.level {
                Level::Fail => failed += 1,
                Level::Warn => warned += 1,
                Level::Ok => {}
            }
        }
        println!();
    }

    if failed > 0 {
        println!(
            "{}{}",
            ui::red(&format!("  {failed} failed")),
            ui::dim(&format!(", {warned} warning(s)"))
        );
        println!();
        return Ok(false);
    }

    if warned > 0 {
        println!(
            "{}",
            ui::yellow(&format!("  healthy with {warned} warning(s)"))
        );
    } else {
        println!("{}", ui::green("  all checks passed"));
    }
    println!();

    Ok(true)
}

fn parse_version(text: &str) -> Option<(u32, u32, u32)> {
    let digits: Vec<u32> = text
        .split(|c: char| !c.is_ascii_digit())
        .filter(|s| !s.is_empty())
        .filter_map(|s| s.parse().ok())
        .collect();

    match digits.as_slice() {
        [major, minor, patch, ..] => Some((*major, *minor, *patch)),
        _ => None,
    }
}

fn have(program: &str, args: &[&str]) -> bool {
    Command::new(program)
        .args(args)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn check_tools(jj: &Jj) -> Vec<Check> {
    let mut checks = Vec::new();

    match jj.version() {
        Err(e) => checks.push(
            Check::fail("jj", format!("{e:#}"))
                .fix("the vjtrees wrapper should provide jj — rebuild it"),
        ),
        Ok(raw) => match parse_version(&raw) {
            None => checks.push(Check::warn("jj", format!("unrecognised version: {raw}"))),
            Some(version) if version < MIN_JJ => checks.push(
                Check::fail(
                    "jj",
                    format!(
                        "{}.{}.{} is too old — lift needs rebase --insert-before",
                        version.0, version.1, version.2
                    ),
                )
                .fix(format!("upgrade to {}.{}.{}", MIN_JJ.0, MIN_JJ.1, MIN_JJ.2)),
            ),
            Some(version) => checks.push(Check::ok(
                "jj",
                format!("{}.{}.{}", version.0, version.1, version.2),
            )),
        },
    }

    for (tool, args, why) in [
        ("ss", vec!["-V"], "detects what holds a port"),
        ("borg", vec!["--version"], "backups before destructive work"),
    ] {
        checks.push(if have(tool, &args) {
            Check::ok(tool, "present")
        } else {
            Check::warn(tool, format!("missing — {why}"))
        });
    }

    checks
}

fn check_repo(root: &Root, jj: &Jj) -> Vec<Check> {
    let mut checks = Vec::new();

    let workspaces = match jj.workspaces() {
        Ok(list) => list,
        Err(e) => {
            return vec![Check::fail("jj repo", format!("{e:#}"))];
        }
    };

    if !workspaces.iter().any(|w| w.name == root.trunk_workspace()) {
        checks.push(
            Check::fail(
                "trunk",
                format!(
                    "no jj workspace named {:?} — vjtrees has no trunk to work from",
                    root.trunk_workspace()
                ),
            )
            .fix("check [project] trunk-workspace"),
        );
        return checks;
    }

    checks.push(Check::ok(
        "workspaces",
        format!("{} registered in jj", workspaces.len()),
    ));

    if let Ok(dirs) = root.workspace_dirs() {
        for dir in dirs {
            let jj_name = root.jj_name_of(&dir);
            if workspaces.iter().any(|w| w.name == jj_name) {
                continue;
            }
            if root.is_own_jj_repo(&dir) {
                checks.push(Check::ok(&dir, "separate jj repo, not a workspace here"));
            } else {
                checks.push(
                    Check::warn(&dir, "has a .jj but is not a registered workspace")
                        .fix("jj workspace add, or remove the directory"),
                );
            }
        }
    }

    match stale::states(root, jj) {
        Err(e) => checks.push(Check::fail("workspaces", format!("{e:#}"))),
        Ok(states) => {
            for ws in states {
                match ws.state {
                    Ok(WorkingCopy::Stale) => checks.push(
                        Check::fail(
                            &ws.dir_name,
                            "working copy is stale — its files predate the current history",
                        )
                        .fix(format!("vjtrees open {}", ws.dir_name)),
                    ),
                    Err(detail) => {
                        checks.push(Check::warn(&ws.dir_name, format!("unreadable: {detail}")))
                    }
                    Ok(_) => {}
                }
            }
        }
    }

    for ws in &workspaces {
        let dir = root.workspace_path(&root.dir_name_of(&ws.name));
        if !dir.exists() {
            checks.push(
                Check::warn(&ws.name, "registered in jj but the directory is gone")
                    .fix(format!("jj workspace forget {}", ws.name)),
            );
        }
    }

    checks
}

fn check_history(root: &Root, jj: &Jj) -> Vec<Check> {
    let mut checks = Vec::new();

    match jj.divergent() {
        Err(e) => checks.push(Check::fail("divergence", format!("{e:#}"))),
        Ok(changes) if changes.is_empty() => {
            checks.push(Check::ok("divergence", "no divergent changes"))
        }
        Ok(changes) => {
            let mut ids: Vec<&str> = changes.iter().map(|c| c.change_id.as_str()).collect();
            ids.sort_unstable();
            ids.dedup();

            checks.push(
                Check::fail(
                    "divergence",
                    format!(
                        "{} change(s) have more than one commit: {}",
                        ids.len(),
                        ids.join(" ")
                    ),
                )
                .fix("vjtrees repair"),
            );

            for change in &changes {
                checks.push(Check::warn(
                    &change.change_id,
                    format!("{}  {}", &change.commit_id[..12], change.label()),
                ));
            }
        }
    }

    if let Ok(ops) = jj.ops_since("", 30) {
        let reconciles = ops
            .iter()
            .filter(|op| op.description.contains("reconcile divergent operations"))
            .count();

        if reconciles > 0 {
            checks.push(
                Check::warn(
                    "concurrency",
                    format!(
                        "{reconciles} recent operation(s) reconciled concurrent jj writes — \
                         that is what creates divergence"
                    ),
                )
                .fix("avoid running jj in this repo while vjtrees is working"),
            );
        }
    }

    let wc = quote_workspace(root.trunk_workspace());
    let ancestors = match jj.ancestors(&wc, root.config.limits.ancestor_scan) {
        Ok(list) => list,
        Err(e) => {
            checks.push(Check::fail("trunk target", format!("{e:#}")));
            return checks;
        }
    };

    match pick_target(&ancestors) {
        Ok(target) => {
            checks.push(Check::ok(
                "trunk target",
                format!(
                    "{} {:?} ({} undescribed above)",
                    target.change_id, target.description, target.undescribed_above
                ),
            ));

            if let Ok(workspaces) = jj.workspaces() {
                for ws in workspaces {
                    if ws.name == root.trunk_workspace() {
                        continue;
                    }
                    let ws_wc = quote_workspace(&ws.name);
                    match jj.merge_base(&ws_wc, &wc) {
                        Err(e) => checks.push(Check::warn(&ws.name, format!("{e:#}"))),
                        Ok(None) => {
                            checks.push(Check::warn(&ws.name, "shares no ancestor with the trunk"))
                        }
                        Ok(Some(base)) if base.commit_id == target.commit_id => {
                            checks.push(Check::ok(&ws.name, "on the current target"))
                        }
                        Ok(Some(base)) => {
                            match jj.is_ancestor(&target.commit_id, &base.commit_id) {
                                Err(e) => checks.push(Check::warn(&ws.name, format!("{e:#}"))),
                                Ok(true) => checks.push(
                                    Check::warn(
                                        &ws.name,
                                        format!(
                                            "based on {}, which is above the target — \
                                             a rebase would move it backwards",
                                            base.change_id
                                        ),
                                    )
                                    .fix(format!("describe {} in the trunk", base.change_id)),
                                ),
                                Ok(false) => checks.push(Check::ok(
                                    &ws.name,
                                    format!(
                                        "based on {} (behind, rebase available)",
                                        base.change_id
                                    ),
                                )),
                            }
                        }
                    }
                }
            }
        }
        Err(NoTarget::Divergent { change }) => checks.push(
            Check::fail(
                "trunk target",
                format!(
                    "the trunk line contains divergent change {}",
                    change.change_id
                ),
            )
            .fix("vjtrees repair"),
        ),
        Err(NoTarget::NoEmptyAbove { tip }) => checks.push(
            Check::warn(
                "trunk target",
                format!("tip {} is described with nothing above it", tip.change_id),
            )
            .fix("jj new"),
        ),
        Err(NoTarget::NoDescribed) => checks.push(
            Check::fail(
                "trunk target",
                format!(
                    "no described change in the last {}",
                    root.config.limits.ancestor_scan
                ),
            )
            .fix("jj describe"),
        ),
        Err(NoTarget::EmptyLog) => {
            checks.push(Check::fail("trunk target", "the change log is empty"))
        }
    }

    checks
}

fn check_runtime(root: &Root) -> Vec<Check> {
    let mut checks = Vec::new();

    let lock = root.lock_path();
    if lock.exists() {
        checks.push(
            Check::warn("lock", format!("{} exists", lock.display()))
                .fix("if no vjtrees is running, remove it"),
        );
    }

    if let Some(setup) = &root.config.setup
        && let Some(marker) = &setup.when_missing
        && let Ok(dirs) = root.workspace_dirs()
    {
        for dir in dirs {
            let path = root.workspace_path(&dir);
            if !path.join(marker).exists() {
                checks.push(
                    Check::warn(&dir, format!("no {marker} — setup has not run"))
                        .fix(format!("vjtrees open {dir}")),
                );
            }
        }
    }

    if checks.is_empty() {
        checks.push(Check::ok("runtime", "nothing to report"));
    }

    checks
}
