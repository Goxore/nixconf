use anyhow::{Context, Result, bail};
use std::path::PathBuf;
use vjtrees::backup;
use vjtrees::guard::{Mutation, guarded};
use vjtrees::jj::Jj;
use vjtrees::root::Root;
use vjtrees::ui;

fn require_configured(root: &Root) -> Result<()> {
    if backup::is_configured(&root.config.backup) {
        return Ok(());
    }

    bail!(
        "no backup is configured — set [backup] repository in {}",
        root.root.join(vjtrees::config::MARKER).display()
    )
}

pub fn run(root: &Root, forget: bool) -> Result<()> {
    require_configured(root)?;

    if forget {
        return run_forget(root);
    }

    println!();
    let spinner = ui::spinner("backing up");
    let snapshot = backup::run_backup(root, &root.config.backup)?;
    spinner.finish(&format!(
        "{} snapshot {}",
        ui::green("backed up"),
        snapshot.id
    ));
    println!();

    Ok(())
}

pub fn snapshots(root: &Root) -> Result<()> {
    require_configured(root)?;

    let archives = backup::archives(&root.config.backup)?;

    println!();
    if archives.is_empty() {
        println!("{}", ui::dim("  no snapshots yet"));
        println!();
        return Ok(());
    }

    for archive in &archives {
        println!("  {}  {}", ui::cyan(&archive.name), ui::dim(&archive.start));
    }

    println!();
    let plural = if archives.len() == 1 { "" } else { "s" };
    println!(
        "{}",
        ui::dim(&format!("  {} snapshot{plural}", archives.len()))
    );
    println!();

    Ok(())
}

fn destination(root: &Root, archive: &str, to: Option<PathBuf>) -> Result<PathBuf> {
    if let Some(dir) = to {
        return Ok(dir);
    }

    let parent = root
        .root
        .parent()
        .context("the project root has no parent — pass --to to say where to restore")?;

    let name = root
        .root
        .file_name()
        .context("the project root has no name — pass --to to say where to restore")?;

    Ok(parent
        .join(format!("{}-restore", name.to_string_lossy()))
        .join(archive))
}

pub fn restore(
    root: &Root,
    snapshot: Option<String>,
    to: Option<PathBuf>,
    list: bool,
    paths: &[String],
) -> Result<()> {
    require_configured(root)?;

    let config = &root.config.backup;
    let archive = match snapshot {
        Some(name) => name,
        None => {
            backup::latest(config)?
                .context("there are no snapshots to restore from yet")?
                .name
        }
    };

    if list {
        println!();
        for file in backup::contents(config, &archive)? {
            println!("  {}", ui::dim(&file));
        }
        println!();
        return Ok(());
    }

    let into = destination(root, &archive, to)?;

    println!();
    println!("  {} {}", ui::dim("snapshot:"), ui::cyan(&archive));
    println!("  {} {}", ui::dim("into:    "), into.display());
    println!();
    println!(
        "{}",
        ui::dim("  your working files are not touched — this only writes into that directory")
    );
    println!();

    if !ui::confirm("Restore?", true)? {
        bail!("aborted");
    }

    let spinner = ui::spinner("restoring");
    let restored = backup::restore(config, &archive, &into, paths)?;
    spinner.finish(&format!(
        "{} into {}",
        ui::green("restored"),
        restored.display()
    ));
    println!();

    Ok(())
}

fn run_forget(root: &Root) -> Result<()> {
    let jj = Jj::new(&root.trunk);
    let config = &root.config.backup;

    let mutation = Mutation::new("backup --forget", "Delete old backup snapshots")
        .effect(format!(
            "keep the last {} snapshots and {} daily",
            config.keep_last, config.keep_daily
        ))
        .effect(if config.prune {
            "compact the repository — deleted data cannot be recovered".to_string()
        } else {
            "mark snapshots for removal without compacting".to_string()
        })
        .allowing_divergent()
        .irreversible("forget");

    guarded(root, &jj, mutation, |_| {
        let output = backup::forget(config)?;
        for line in output.lines().take(20) {
            println!("{}", ui::dim(&format!("    {line}")));
        }
        Ok(())
    })
}
