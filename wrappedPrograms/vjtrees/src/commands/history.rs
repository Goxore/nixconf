use anyhow::{Result, bail};
use std::collections::BTreeMap;
use std::process::Command;
use vjtrees::guard::{Mutation, guarded};
use vjtrees::jj::{Change, Jj, Moving, Placement, quote_workspace};
use vjtrees::lock::Lock;
use vjtrees::paths::{Category, breaks_dependents, categorize};
use vjtrees::root::Root;
use vjtrees::state;
use vjtrees::target::{NoTarget, Target, pick_target};
use vjtrees::ui::{self, Choice};

fn resolve_target(root: &Root, jj: &Jj) -> Result<Target> {
    let wc = quote_workspace(root.trunk_workspace());
    let ancestors = jj.ancestors(&wc, root.config.limits.ancestor_scan)?;

    match pick_target(&ancestors) {
        Ok(target) => Ok(target),
        Err(NoTarget::NoEmptyAbove { tip }) => {
            println!();
            println!(
                "{} the trunk tip is a described change with nothing above it",
                ui::red("  error:")
            );
            println!();
            println!("    {}  {}", ui::cyan(&tip.change_id), tip.description);
            println!();
            println!(
                "{}",
                ui::dim("  using it would pin a change you are still editing —")
            );
            println!(
                "{}",
                ui::dim("  every later edit would rewrite the base of whatever sits on top.")
            );
            println!();

            if !ui::confirm("Create an empty change on top of the trunk now?", false)? {
                std::process::exit(1);
            }

            jj.new_change(None)?;
            println!("{}", ui::green("  created an empty change on the trunk"));

            let ancestors = jj.ancestors(&wc, root.config.limits.ancestor_scan)?;
            pick_target(&ancestors).map_err(|e| describe_no_target(root, &e))
        }
        Err(other) => Err(describe_no_target(root, &other)),
    }
}

fn describe_no_target(root: &Root, reason: &NoTarget) -> anyhow::Error {
    match reason {
        NoTarget::EmptyLog => anyhow::anyhow!("the trunk change log is empty"),
        NoTarget::NoDescribed => anyhow::anyhow!(
            "no described change in the last {} of the trunk — describe one with: jj describe",
            root.config.limits.ancestor_scan
        ),
        NoTarget::NoEmptyAbove { tip } => anyhow::anyhow!(
            "the trunk tip {} is described with nothing above it — run: jj new",
            tip.change_id
        ),
        NoTarget::Divergent { change } => anyhow::anyhow!(
            "the trunk line contains divergent change {} — clear it with: vjtrees repair",
            change.change_id
        ),
    }
}

fn describe(change: &Change) -> String {
    if change.description.is_empty() {
        ui::dim("(no description set)")
    } else {
        change.description.clone()
    }
}

fn print_target(target: &Target) {
    println!(
        "  {}  {}  {}",
        ui::dim("target"),
        ui::cyan(&target.change_id),
        target.description
    );
    println!(
        "{}",
        ui::dim(&format!(
            "  {} undescribed change(s) above it in the trunk",
            target.undescribed_above
        ))
    );
    println!();
}

fn choose_workspace(root: &Root, jj: &Jj, given: Option<String>, prompt: &str) -> Result<String> {
    if let Some(name) = given {
        return Ok(name);
    }

    if let Some(current) = state::read(root).current_workspace
        && current != root.trunk_dir_name()
    {
        return Ok(current);
    }

    let choices: Vec<Choice<String>> = jj
        .workspaces()?
        .into_iter()
        .filter(|w| w.name != root.trunk_workspace())
        .map(|w| {
            let label = format!("  {:<24} {}", w.name, ui::dim(&w.description));
            Choice::new(label, w.name)
        })
        .collect();

    match ui::select(prompt, choices)?.map(|c| c.value) {
        Some(name) => Ok(name),
        None => {
            println!("{}", ui::dim("  nothing selected"));
            std::process::exit(0);
        }
    }
}

pub fn rebase(root: &Root, name: Option<String>) -> Result<()> {
    let _lock = Lock::acquire(&root.lock_path(), "rebase")?;
    let jj = Jj::new(&root.trunk);
    let name = choose_workspace(root, &jj, name, "Which workspace should be rebased?")?;
    let jj_name = root.jj_name_of(&name);

    if jj_name == root.trunk_workspace() {
        bail!("select a workspace other than the trunk");
    }

    let workspaces = jj.workspaces()?;
    if !workspaces.iter().any(|w| w.name == jj_name) {
        bail!("no jj workspace named {jj_name}");
    }

    println!();
    println!(
        "{} {}",
        ui::bold("  rebase"),
        ui::dim(&format!("{name} → latest described trunk change"))
    );
    println!();

    let target = resolve_target(root, &jj)?;
    print_target(&target);

    let wc = quote_workspace(&jj_name);
    let trunk_wc = quote_workspace(root.trunk_workspace());

    let Some(fork) = jj.merge_base(&wc, &trunk_wc)? else {
        bail!("{name} shares no ancestor with the trunk");
    };

    if fork.commit_id == target.commit_id {
        println!("{}", ui::green("  already on the latest described change"));
        println!();
        return Ok(());
    }

    if jj.is_ancestor(&target.commit_id, &fork.commit_id)? {
        println!(
            "{} {name} is based on a change newer than the target",
            ui::red("  error:")
        );
        println!();
        println!(
            "    its base  {}  {}",
            ui::cyan(&fork.change_id),
            fork.label()
        );
        println!(
            "    target    {}  {}",
            ui::cyan(&target.change_id),
            target.description
        );
        println!();
        println!(
            "{}",
            ui::dim("  rebasing would move it backwards — describe its base in the trunk instead")
        );
        println!();
        std::process::exit(1);
    }

    let current_version = jj.count_ancestors(&fork.commit_id)?;
    let target_version = jj.count_ancestors(&target.commit_id)?;

    println!(
        "  {} v{current_version}  →  {} v{target_version}  {}",
        ui::dim("current base"),
        ui::dim("target"),
        ui::dim(&format!(
            "(+{} changes)",
            target_version.saturating_sub(current_version)
        ))
    );
    println!();

    let incoming = jj.commits_between(&fork.commit_id, &target.commit_id)?;
    let mut breaking = Vec::new();

    let scan = ui::spinner(&format!("scanning {} trunk change(s)", incoming.len()));
    for change in &incoming {
        for file in jj.changed_files(&change.commit_id)? {
            if breaks_dependents(&file, &root.config.paths.fragile) && !breaking.contains(&file) {
                breaking.push(file);
            }
        }
    }
    scan.clear();

    if !incoming.is_empty() {
        println!("{}", ui::heading("  trunk changes since your base"));
        println!();
        for change in incoming
            .iter()
            .rev()
            .take(10)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
        {
            println!("    {}  {}", ui::cyan(&change.change_id), describe(change));
        }
        if incoming.len() > 10 {
            println!(
                "{}",
                ui::dim(&format!("    ... and {} more", incoming.len() - 10))
            );
        }
        println!();
    }

    if !breaking.is_empty() {
        println!(
            "{}",
            ui::yellow("  touches code your workspace depends on:")
        );
        for file in breaking.iter().take(10) {
            println!("{}", ui::dim(&format!("    {file}")));
        }
        if breaking.len() > 10 {
            println!(
                "{}",
                ui::dim(&format!("    ... and {} more", breaking.len() - 10))
            );
        }
        println!();
    }

    let moving = jj.commits_between(&fork.commit_id, &wc)?;
    let Some(first) = moving.first() else {
        bail!("{name} has no changes of its own to rebase");
    };

    let mutation = Mutation::new(
        "rebase",
        &format!("Rebase {name} onto {}", target.change_id),
    )
    .effect(format!(
        "move {} change(s) from {} onto {}",
        moving.len(),
        fork.change_id,
        target.change_id
    ))
    .effect(format!("v{current_version} → v{target_version}"));

    let first_commit = first.commit_id.clone();
    let target_commit = target.commit_id.clone();

    let outcome = guarded(root, &jj, mutation, |_| {
        jj.rebase(
            Moving::Subtree(&first_commit),
            Placement::Onto(&target_commit),
        )
    })?;

    if outcome.conflicted {
        println!("{}", ui::yellow("  the rebase produced conflicts"));
        println!(
            "{} {}",
            ui::dim("  resolve them in"),
            ui::cyan(&root.workspace_path(&name).display().to_string())
        );
        println!("{} {}", ui::dim("  then run:"), ui::cyan("jj resolve"));
        return Ok(());
    }

    println!("{} {name} → {}", ui::green("  rebased"), target.change_id);

    if let Some(check) = &root.config.check {
        run_check(root, &name, &check.command)?;
    }

    Ok(())
}

fn run_check(root: &Root, name: &str, command: &[String]) -> Result<()> {
    let Some((program, args)) = command.split_first() else {
        return Ok(());
    };

    println!("{} {}", ui::dim("  running"), command.join(" "));

    let output = Command::new(program)
        .args(args)
        .current_dir(root.workspace_path(name))
        .output();

    match output {
        Err(e) => {
            println!("{} {e}", ui::yellow("  could not run the check:"));
        }
        Ok(output) if output.status.success() => {
            println!("{}", ui::green("  check passed"));
        }
        Ok(output) => {
            println!("{}", ui::yellow("  check failed:"));
            let text = format!(
                "{}{}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
            for line in text.lines().take(15) {
                println!("{}", ui::dim(&format!("    {line}")));
            }
        }
    }

    Ok(())
}

pub fn lift(root: &Root, name: Option<String>) -> Result<()> {
    let _lock = Lock::acquire(&root.lock_path(), "lift")?;
    let jj = Jj::new(&root.trunk);
    let name = choose_workspace(
        root,
        &jj,
        name,
        "Lift shared changes out of which workspace?",
    )?;
    let jj_name = root.jj_name_of(&name);

    if jj_name == root.trunk_workspace() {
        bail!("select a workspace other than the trunk");
    }

    println!();
    println!(
        "{} {}",
        ui::bold("  lift"),
        ui::dim(&format!("{name} → trunk"))
    );
    println!();

    let target = resolve_target(root, &jj)?;
    print_target(&target);

    let wc = quote_workspace(&jj_name);
    let trunk_wc = quote_workspace(root.trunk_workspace());

    let Some(fork) = jj.merge_base(&wc, &trunk_wc)? else {
        bail!("{name} shares no ancestor with the trunk");
    };

    let changes = jj.commits_between(&fork.commit_id, &wc)?;
    if changes.is_empty() {
        println!("{}", ui::dim("  nothing to analyse"));
        return Ok(());
    }

    let mut categories: BTreeMap<String, Category> = BTreeMap::new();
    let scan = ui::spinner(&format!("analysing {} change(s)", changes.len()));
    for change in &changes {
        let files = jj.changed_files(&change.commit_id)?;
        categories.insert(
            change.commit_id.clone(),
            categorize(&files, &root.config.paths.owned),
        );
    }
    scan.clear();

    let count = |wanted: Category| categories.values().filter(|c| **c == wanted).count();

    println!("{}", ui::rule());
    println!(
        "  {} shared   {} owned   {}",
        ui::yellow(&count(Category::Shared).to_string()),
        ui::dim(&count(Category::Owned).to_string()),
        if count(Category::Mixed) > 0 {
            ui::red(&format!("{} mixed", count(Category::Mixed)))
        } else {
            String::new()
        }
    );
    println!("{}", ui::rule());
    println!();

    if count(Category::Shared) == 0 && count(Category::Mixed) == 0 {
        println!(
            "{}",
            ui::green("  no shared changes found — nothing to lift")
        );
        return Ok(());
    }

    let choices: Vec<Choice<String>> = changes
        .iter()
        .map(|change| {
            let category = categories[&change.commit_id];
            let marker = match category {
                Category::Shared => ui::yellow("shared"),
                Category::Mixed => ui::red("mixed "),
                Category::Owned => ui::dim("owned "),
            };
            Choice::new(
                format!(
                    "  {marker}  {}  {}",
                    ui::cyan(&change.change_id),
                    describe(change)
                ),
                change.commit_id.clone(),
            )
        })
        .collect();

    let selected: Vec<String> =
        ui::multi_select("Which changes should move into the trunk?", choices)?
            .into_iter()
            .map(|c| c.value)
            .collect();
    if selected.is_empty() {
        println!("{}", ui::dim("  nothing selected"));
        return Ok(());
    }

    let picked: Vec<&Change> = changes
        .iter()
        .filter(|c| selected.contains(&c.commit_id))
        .collect();

    let has_mixed = picked
        .iter()
        .any(|c| categories[&c.commit_id] == Category::Mixed);

    let mut mutation = Mutation::new(
        "lift",
        &format!("Lift {} change(s) onto {}", picked.len(), target.change_id),
    )
    .effect(format!(
        "splice them in directly above {}, below the trunk's work in progress",
        target.change_id
    ))
    .effect("workspaces already forked off the target are not moved".to_string());

    if has_mixed {
        mutation = mutation.effect(ui::red(
            "some selected changes touch both shared and owned files — they move in full",
        ));
    }

    let insert_before = target.insert_before.clone();
    let commits: Vec<String> = picked.iter().map(|c| c.commit_id.clone()).collect();

    guarded(root, &jj, mutation, |recovery| {
        for commit in &commits {
            if let Err(e) = jj.rebase(Moving::Single(commit), Placement::Before(&insert_before)) {
                bail!(
                    "{e:#}\n       nothing further was moved — undo with: jj op restore {}",
                    recovery.op_id
                );
            }
        }
        Ok(())
    })?;

    println!(
        "{} {} change(s) onto {}",
        ui::green("  lifted"),
        commits.len(),
        target.change_id
    );

    Ok(())
}

pub fn repair(root: &Root) -> Result<()> {
    let _lock = Lock::acquire(&root.lock_path(), "repair")?;
    let jj = Jj::new(&root.trunk);
    let divergent = jj.divergent()?;

    println!();
    println!(
        "{} {}",
        ui::bold("  repair"),
        ui::dim(&root.root.display().to_string())
    );
    println!();

    if divergent.is_empty() {
        println!(
            "{}",
            ui::green("  no divergent changes — nothing to repair")
        );
        println!();
        return Ok(());
    }

    let mut grouped: BTreeMap<String, Vec<Change>> = BTreeMap::new();
    for change in divergent {
        grouped
            .entry(change.change_id.clone())
            .or_default()
            .push(change);
    }

    let workspaces = jj.workspaces()?;

    for (change_id, candidates) in grouped {
        println!("{} {}", ui::red("  divergent change"), ui::cyan(&change_id));
        println!(
            "{}",
            ui::dim(&format!(
                "  {} commits claim this change id",
                candidates.len()
            ))
        );
        println!();

        for candidate in &candidates {
            let on = workspaces
                .iter()
                .filter(|w| w.commit_id == candidate.commit_id)
                .map(|w| w.name.clone())
                .collect::<Vec<_>>();

            println!(
                "    {}  {}",
                ui::bold(&candidate.commit_id[..12]),
                candidate.label()
            );
            if !on.is_empty() {
                println!(
                    "{}",
                    ui::dim(&format!("      checked out by: {}", on.join(", ")))
                );
            }
            match jj.diff_stat(&candidate.commit_id) {
                Ok(stat) if !stat.is_empty() => {
                    for line in stat.lines().take(6) {
                        println!("{}", ui::dim(&format!("      {line}")));
                    }
                }
                Ok(_) => println!("{}", ui::dim("      (no changes)")),
                Err(e) => println!("{}", ui::dim(&format!("      cannot diff: {e:#}"))),
            }
            println!();
        }

        let choices: Vec<Choice<String>> = candidates
            .iter()
            .map(|c| {
                Choice::new(
                    format!("  keep {}  {}", ui::bold(&c.commit_id[..12]), c.label()),
                    c.commit_id.clone(),
                )
            })
            .collect();

        let keep = ui::select(
            &format!("Which commit is the real {change_id}? (Esc to skip)"),
            choices,
        )?
        .map(|c| c.value);

        let Some(keep) = keep else {
            println!("{}", ui::dim("  skipped"));
            println!();
            continue;
        };

        let discard: Vec<String> = candidates
            .iter()
            .map(|c| c.commit_id.clone())
            .filter(|id| *id != keep)
            .collect();

        let mut mutation = Mutation::new("repair", &format!("Resolve divergent {change_id}"))
            .allowing_divergent()
            .effect(format!("keep    {}", &keep[..12]));

        for id in &discard {
            mutation = mutation.effect(format!("abandon {}", &id[..12]));
        }

        let to_abandon = discard.clone();
        guarded(root, &jj, mutation, |_| {
            for id in &to_abandon {
                jj.abandon(id)?;
            }
            Ok(())
        })?;

        println!("{} {change_id}", ui::green("  resolved"));
        println!();
    }

    Ok(())
}
