use anyhow::{Context, Result, bail};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use vjtrees::config::{Config, MARKER};
use vjtrees::jj::{Jj, quote_workspace};
use vjtrees::target::{NoTarget, pick_target};
use vjtrees::ui;

const MINIMAL: &str = r#"# vjtrees project root and configuration.
# Every path is relative to this file's directory.

[project]
trunk = "TRUNK"
trunk-workspace = "default"

[open]
command = ["EDITOR", "{workspace}"]

[paths]
owned = []
fragile = []

[backup]
# Uncomment to enable backups. The repository is created on first use.
# repository = "/persist/vjtrees/PROJECT"
encryption = "none"
excludes = ["node_modules", "target", ".direnv"]
prune = false
require = "irreversible"
"#;

const VJCANVAS: &str = r#"# vjtrees project root and configuration.
# Every path is relative to this file's directory.

[project]
trunk = "vjcanvas"
trunk-workspace = "default"

[open]
command = ["nvim", "-c", "luafile {workspace}/vjc.lua", "-c", "filetype detect", "{entry}"]
cwd = "video"
entry = "video/video.vjc"

[setup]
command = ["bun", "install"]
when-missing = "node_modules"
when-newer = "package.json"

[server]
command = ["bun", "dev"]
ports = [5173]
wait-ports = [5174]
wait-if-present = "vite/lsp.ts"

[check]
command = ["bun", "run", "tsc", "--noEmit"]

[paths]
owned = ["video/"]
fragile = [
  "src/dsl/",
  "src/dsl.ts",
  "src/dsl-scene.ts",
  "src/scene.ts",
  "src/runtime/",
  "src/renderer/",
  "lua/",
  "vjc.lua",
  "vj/",
  "package.json",
  "bun.lock",
  "tsconfig.json",
  "vite.config.ts",
]

[backup]
# Uncomment to enable backups. The repository is created on first use.
# repository = "/persist/vjtrees/vjcanvas"
encryption = "none"
excludes = [
  "node_modules",
  "dist",
  ".tts-cache",
  ".enhance-cache",
  ".anchor-snapshots",
  "*.mp4",
  "*.webm",
  "*.wav",
  "*.mp3",
  "*.ogg",
  ".git/objects",
  ".vjtrees-server.log",
]
prune = false
require = "irreversible"
"#;

pub fn run(
    dir: Option<PathBuf>,
    preset: &str,
    trunk: Option<String>,
    editor: String,
) -> Result<()> {
    let dir = match dir {
        Some(dir) => dir,
        None => std::env::current_dir()?,
    };

    let marker = dir.join(MARKER);

    if marker.exists() {
        let existing = fs::read_to_string(&marker).unwrap_or_default();
        if !existing.trim().is_empty() {
            bail!(
                "{} already has configuration — edit it by hand rather than overwriting it",
                marker.display()
            );
        }
    }

    let text = match preset {
        "vjcanvas" => VJCANVAS.to_string(),
        "minimal" => MINIMAL
            .replace("TRUNK", trunk.as_deref().unwrap_or("trunk"))
            .replace("EDITOR", &editor),
        other => bail!("unknown preset {other:?} — known presets are: minimal, vjcanvas"),
    };

    let config = Config::parse(&text).context("the generated config is not valid")?;

    println!();
    println!("{}", ui::bold("  vjtrees init"));
    println!();
    println!("    root   {}", dir.display());
    println!("    trunk  {}", config.project.trunk);
    println!("    open   {}", config.open.command.join(" "));
    println!();

    if !ui::confirm(&format!("Write {}?", marker.display()), true)? {
        println!("{}", ui::dim("  aborted"));
        return Ok(());
    }

    fs::write(&marker, &text).with_context(|| format!("cannot write {}", marker.display()))?;
    println!("{} {}", ui::green("  wrote"), marker.display());

    let trunk_dir = dir.join(&config.project.trunk);
    ensure_repo(&trunk_dir)?;

    let jj = Jj::new(&trunk_dir);
    establish_invariant(
        &jj,
        &config.project.trunk_workspace,
        config.limits.ancestor_scan,
    )?;

    println!();
    println!("{}", ui::green("  ready"));
    println!("{}", ui::dim("  next: vjtrees doctor"));
    println!();

    Ok(())
}

fn ensure_repo(trunk: &Path) -> Result<()> {
    if trunk.join(".jj").exists() {
        println!(
            "{} {}",
            ui::dim("  adopting jj repository"),
            trunk.display()
        );
        return Ok(());
    }

    fs::create_dir_all(trunk).with_context(|| format!("cannot create {}", trunk.display()))?;

    let output = Command::new("jj")
        .args(["git", "init"])
        .arg(trunk)
        .output()
        .context("could not run jj")?;

    if !output.status.success() {
        bail!(
            "jj git init failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }

    println!(
        "{} {}",
        ui::green("  created jj repository"),
        trunk.display()
    );
    Ok(())
}

fn establish_invariant(jj: &Jj, trunk_workspace: &str, scan: usize) -> Result<()> {
    let wc = quote_workspace(trunk_workspace);
    let ancestors = jj.ancestors(&wc, scan)?;

    match pick_target(&ancestors) {
        Ok(target) => {
            println!(
                "{} {}",
                ui::dim("  trunk target already valid:"),
                target.change_id
            );
            Ok(())
        }
        Err(NoTarget::Divergent { change }) => bail!(
            "the trunk line has a divergent change ({}) — clear it with `vjtrees repair` first",
            change.change_id
        ),
        Err(NoTarget::NoEmptyAbove { .. }) => {
            jj.new_change(None)?;
            println!("{}", ui::green("  created an empty change on the trunk"));
            Ok(())
        }
        Err(NoTarget::NoDescribed) | Err(NoTarget::EmptyLog) => {
            jj.describe(&wc, "trunk")?;
            jj.new_change(None)?;
            println!(
                "{}",
                ui::green(
                    "  seeded the trunk line: described \"trunk\" with an empty change above it"
                )
            );
            Ok(())
        }
    }
}
