use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::path::PathBuf;
use vjvr::{
    controller::Controller,
    ipc,
    model::{Config, Request},
};

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Action,
}

#[derive(Subcommand)]
enum Action {
    Serve {
        #[arg(long)]
        config: Option<PathBuf>,
    },
    Status,
    Watch,
    Request {
        json: String,
    },
    Probe,
}

#[tokio::main]
async fn main() {
    if let Err(error) = run().await {
        eprintln!("vjvr: {error:#}");
        std::process::exit(1);
    }
}

async fn run() -> Result<()> {
    match Cli::parse().command {
        Action::Serve { config } => {
            let config = config
                .or_else(|| std::env::var_os("VJVR_CONFIG").map(PathBuf::from))
                .context("config_unavailable")?;
            let config: Config = serde_json::from_slice(&std::fs::read(config)?)?;
            let base = std::env::var_os("XDG_STATE_HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|| {
                    PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state")
                });
            let dir = base.join("vjvr");
            std::fs::create_dir_all(&dir)?;
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700))?;
            let controller = Controller::new(config, dir.join("state.json")).await?;
            ipc::serve(controller, &ipc::socket_path()?).await?;
        }
        Action::Status => ipc::client(&ipc::socket_path()?, Request::Status).await?,
        Action::Watch => ipc::client(&ipc::socket_path()?, Request::Watch).await?,
        Action::Request { json } => {
            ipc::client(&ipc::socket_path()?, serde_json::from_str(&json)?).await?
        }
        Action::Probe => {
            let mut headsets = vjvr::adb::discover().await?;
            for headset in &mut headsets {
                if headset.status == "device" {
                    vjvr::adb::inventory(headset).await?;
                }
            }
            println!("{}", serde_json::to_string(&headsets)?);
        }
    }
    Ok(())
}
