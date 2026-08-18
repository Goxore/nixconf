mod commands;

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::Shell as CompletionShell;
use std::path::PathBuf;
use vjtrees::root::Root;

#[derive(Parser)]
#[command(
    name = "vjtrees",
    about = "Config-driven jj workspace manager",
    version,
    disable_help_subcommand = true
)]
struct Cli {
    #[arg(long, global = true, value_name = "DIR")]
    cwd: Option<PathBuf>,

    /// Answer yes/no prompts automatically. Irreversible work still asks.
    #[arg(long, global = true)]
    yes: bool,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Create a project root and write its vjtrees.toml configuration
    Init {
        #[arg(long, value_name = "DIR")]
        dir: Option<PathBuf>,
        /// minimal | vjcanvas
        #[arg(long, default_value = "minimal")]
        preset: String,
        #[arg(long, value_name = "NAME")]
        trunk: Option<String>,
        #[arg(long, default_value = "nvim")]
        editor: String,
    },
    /// List every workspace in this project
    #[command(alias = "ls")]
    List,
    /// Show workspace, working-copy and server state
    Status,
    /// Full healthcheck; exits non-zero on failure
    #[command(aliases = ["check", "healthcheck"])]
    Doctor,
    /// Print the project root directory
    Root,
    /// Print the trunk repository directory
    Trunk,
    /// Switch to a workspace and launch the configured open command
    #[command(alias = "switch")]
    Open {
        name: Option<String>,
        #[arg(long)]
        no_open: bool,
    },
    /// Create a workspace and open it
    New {
        name: String,
        #[arg(long)]
        no_open: bool,
    },
    /// Delete a workspace. Irreversible; requires a backup by default
    #[command(aliases = ["rm", "remove"])]
    Delete { name: Option<String> },
    /// Stop the dev server and any strays left in the project tree
    Stop,
    /// Move a workspace up onto the latest described trunk change
    Rebase { name: Option<String> },
    /// Move shared changes down from a workspace into the trunk
    Lift { name: Option<String> },
    /// Inspect and resolve divergent changes
    Repair,
    /// Print the completion script for a shell
    Completions {
        /// bash | elvish | fish | powershell | zsh
        #[arg(value_name = "SHELL")]
        shell: CompletionShell,
    },
    /// Back the project up to the configured borg repository
    Backup {
        /// Delete old snapshots according to [backup] retention
        #[arg(long)]
        forget: bool,
    },
    /// List the backup snapshots of this project
    #[command(alias = "snaps")]
    Snapshots,
    /// Restore files from a backup into a directory, never over your work
    Restore {
        /// Snapshot to restore from; the most recent one by default
        #[arg(long, value_name = "NAME")]
        snapshot: Option<String>,
        /// Where to put the restored files
        #[arg(long, value_name = "DIR")]
        to: Option<PathBuf>,
        /// List the snapshot's files instead of restoring them
        #[arg(long)]
        list: bool,
        /// Restore only these paths
        #[arg(value_name = "PATH")]
        paths: Vec<String>,
    },
}

fn main() {
    if let Err(e) = run() {
        eprintln!("vjtrees: {e:#}");
        std::process::exit(1);
    }
}

fn start_dir(cli: &Cli) -> Result<PathBuf> {
    match &cli.cwd {
        Some(dir) => Ok(dir.clone()),
        None => Ok(std::env::current_dir()?),
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();

    if let Command::Completions { shell } = cli.command {
        let mut cmd = Cli::command();
        let name = cmd.get_name().to_string();
        clap_complete::generate(shell, &mut cmd, name, &mut std::io::stdout());
        return Ok(());
    }

    vjtrees::ui::assume_yes(cli.yes);
    let start = start_dir(&cli)?;

    if let Command::Init {
        dir,
        preset,
        trunk,
        editor,
    } = &cli.command
    {
        return commands::init::run(
            dir.clone().or(cli.cwd.clone()),
            preset,
            trunk.clone(),
            editor.clone(),
        );
    }

    let root = Root::find(&start)?;

    match cli.command {
        Command::Init { .. } => unreachable!("handled above"),
        Command::Completions { .. } => unreachable!("handled above"),
        Command::List => commands::inspect::list(&root),
        Command::Status => commands::inspect::status(&root),
        Command::Doctor => {
            if commands::inspect::doctor(&root)? {
                Ok(())
            } else {
                std::process::exit(1)
            }
        }
        Command::Root => {
            println!("{}", root.root.display());
            Ok(())
        }
        Command::Trunk => {
            println!("{}", root.trunk.display());
            Ok(())
        }
        Command::Open { name, no_open } => commands::workspace::open(&root, name, no_open),
        Command::New { name, no_open } => commands::workspace::new(&root, name, no_open),
        Command::Delete { name } => commands::workspace::delete(&root, name),
        Command::Stop => commands::workspace::stop(&root),
        Command::Rebase { name } => commands::history::rebase(&root, name),
        Command::Lift { name } => commands::history::lift(&root, name),
        Command::Repair => commands::history::repair(&root),
        Command::Backup { forget } => commands::backup_cmd::run(&root, forget),
        Command::Snapshots => commands::backup_cmd::snapshots(&root),
        Command::Restore {
            snapshot,
            to,
            list,
            paths,
        } => commands::backup_cmd::restore(&root, snapshot, to, list, &paths),
    }
}
