use crate::backup;
use crate::config::Require;
use crate::jj::Jj;
use crate::lock::Lock;
use crate::root::Root;
use crate::stale;
use crate::ui;
use anyhow::{Result, bail};
use std::collections::BTreeSet;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Reversibility {
    JjOp,
    Irreversible,
}

#[derive(Debug, Clone)]
pub struct Mutation {
    pub command: String,
    pub headline: String,
    pub effects: Vec<String>,
    pub reversibility: Reversibility,
    pub confirm_word: Option<String>,
    pub allow_divergent: bool,
}

impl Mutation {
    pub fn new(command: &str, headline: &str) -> Self {
        Self {
            command: command.to_string(),
            headline: headline.to_string(),
            effects: Vec::new(),
            reversibility: Reversibility::JjOp,
            confirm_word: None,
            allow_divergent: false,
        }
    }

    pub fn effect(mut self, line: impl Into<String>) -> Self {
        self.effects.push(line.into());
        self
    }

    pub fn irreversible(mut self, confirm_word: &str) -> Self {
        self.reversibility = Reversibility::Irreversible;
        self.confirm_word = Some(confirm_word.to_string());
        self
    }

    pub fn allowing_divergent(mut self) -> Self {
        self.allow_divergent = true;
        self
    }
}

#[derive(Debug, Clone)]
pub struct Recovery {
    pub op_id: String,
    pub snapshot: Option<String>,
}

pub fn guarded<T>(
    root: &Root,
    jj: &Jj,
    mutation: Mutation,
    body: impl FnOnce(&Recovery) -> Result<T>,
) -> Result<T> {
    let mut lock = Lock::acquire(&root.lock_path(), &mutation.command)?;

    let before_divergent = divergent_ids(jj)?;
    if !mutation.allow_divergent && !before_divergent.is_empty() {
        bail!(
            "this repository has divergent changes — refusing to rewrite history on top of them\n       \
             inspect and clear them with: vjtrees repair"
        );
    }

    stale::refresh_all(root, jj)?;

    let op_before = jj.op_head()?;

    println!();
    println!("{}", ui::bold(&format!("  {}", mutation.headline)));
    println!();
    for effect in &mutation.effects {
        println!("    {effect}");
    }
    println!();

    match mutation.reversibility {
        Reversibility::JjOp => println!(
            "{}",
            ui::dim(&format!("  reversible with: jj op restore {op_before}"))
        ),
        Reversibility::Irreversible => {
            println!("{}", ui::red("  THIS CANNOT BE UNDONE BY JJ"));
            println!(
                "{}",
                ui::dim("  only the backup taken below can bring it back")
            );
        }
    }
    println!();

    let snapshot = take_backup(root, &mutation)?;

    let approved = match &mutation.confirm_word {
        Some(word) => ui::confirm_typed(&mutation.headline, word)?,
        None => ui::confirm(&format!("{}?", mutation.headline), false)?,
    };

    if !approved {
        println!("{}", ui::dim("  aborted — nothing was changed"));
        lock.release();
        std::process::exit(0);
    }

    let recovery = Recovery {
        op_id: op_before.clone(),
        snapshot: snapshot.clone(),
    };

    let result = body(&recovery);

    let refreshed = stale::refresh_all(root, jj);
    let raced = detect_race(jj, &op_before, &before_divergent);

    report_recovery(&recovery, &raced);

    if let Err(e) = refreshed {
        lock.release();
        bail!(
            "{e:#}\n       the change landed but a workspace could not be updated — \
             its files still show the old history"
        );
    }

    lock.release();
    result
}

pub fn backup_required(policy: Require, reversibility: Reversibility) -> bool {
    match (policy, reversibility) {
        (Require::Never, _) => false,
        (Require::Always, _) => true,
        (Require::Irreversible, Reversibility::Irreversible) => true,
        (Require::Irreversible, Reversibility::JjOp) => false,
    }
}

fn take_backup(root: &Root, mutation: &Mutation) -> Result<Option<String>> {
    let required = backup_required(root.config.backup.require, mutation.reversibility);

    if !backup::is_configured(&root.config.backup) {
        let marker = root.root.join(crate::config::MARKER);

        if required {
            bail!(
                "no backup is configured, and this cannot be undone\n       \
                 set [backup] repository in {}\n       \
                 or change [backup] require there",
                marker.display()
            );
        }

        println!(
            "{}",
            ui::yellow("  warning: no backup configured — proceeding without one")
        );
        println!(
            "{}",
            ui::dim(&format!(
                "  set [backup] repository in {}",
                marker.display()
            ))
        );
        println!();
        return Ok(None);
    }

    let spinner = ui::spinner("backing up");

    match backup::run_backup(root, &root.config.backup) {
        Ok(snapshot) => {
            spinner.finish(&format!(
                "{} snapshot {}",
                ui::green("backed up"),
                snapshot.id
            ));
            println!();
            Ok(Some(snapshot.id))
        }
        Err(e) => {
            spinner.finish(&ui::red("backup failed"));
            println!("  {e:#}");

            if required {
                bail!("refusing to continue without a backup — this cannot be undone");
            }

            if !ui::confirm("Continue without a backup?", false)? {
                bail!("aborted");
            }
            Ok(None)
        }
    }
}

pub fn divergent_ids(jj: &Jj) -> Result<BTreeSet<String>> {
    Ok(jj.divergent()?.into_iter().map(|c| c.commit_id).collect())
}

#[derive(Debug, Default)]
pub struct Race {
    pub reconciles: Vec<String>,
    pub new_divergent: Vec<String>,
}

impl Race {
    pub fn happened(&self) -> bool {
        !self.reconciles.is_empty() || !self.new_divergent.is_empty()
    }
}

pub fn detect_race(jj: &Jj, op_before: &str, before_divergent: &BTreeSet<String>) -> Race {
    let mut race = Race::default();

    if let Ok(ops) = jj.ops_since(op_before, 100) {
        for op in ops {
            if op.description.contains("reconcile divergent operations") {
                race.reconciles.push(op.id);
            }
        }
    }

    if let Ok(after) = divergent_ids(jj) {
        for id in after.difference(before_divergent) {
            race.new_divergent.push(id.clone());
        }
    }

    race
}

fn report_recovery(recovery: &Recovery, race: &Race) {
    println!();

    if race.happened() {
        println!(
            "{}",
            ui::red("  A CONCURRENT JJ OPERATION HAPPENED DURING THIS COMMAND")
        );
        println!();

        if !race.reconciles.is_empty() {
            println!(
                "    jj reconciled {} divergent operation(s): {}",
                race.reconciles.len(),
                race.reconciles.join(" ")
            );
        }
        if !race.new_divergent.is_empty() {
            println!(
                "    {} commit(s) became divergent: {}",
                race.new_divergent.len(),
                race.new_divergent
                    .iter()
                    .map(|id| id[..12.min(id.len())].to_string())
                    .collect::<Vec<_>>()
                    .join(" ")
            );
        }

        println!();
        println!(
            "{}",
            ui::dim("    something else ran jj here at the same time — an editor, direnv,")
        );
        println!(
            "{}",
            ui::dim(
                "    a shell prompt, or another terminal. Deal with it now, while it is one command away."
            )
        );
        println!();
        println!(
            "    {} {}",
            ui::bold("undo everything:"),
            ui::cyan(&format!("jj op restore {}", recovery.op_id))
        );
        println!(
            "    {} {}",
            ui::bold("or inspect:      "),
            ui::cyan("vjtrees repair")
        );
        println!();
        return;
    }

    println!(
        "{} {}",
        ui::dim("  undo with:"),
        ui::cyan(&format!("jj op restore {}", recovery.op_id))
    );

    if let Some(snapshot) = &recovery.snapshot {
        println!(
            "{} {}",
            ui::dim("  files in: "),
            ui::cyan(&format!("vjtrees restore --snapshot {snapshot}"))
        );
    }

    println!();
}
