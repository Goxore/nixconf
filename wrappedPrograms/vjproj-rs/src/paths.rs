use anyhow::{Context, Result};
use std::env;
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct Dirs {
    pub runtime: PathBuf,
}

impl Dirs {
    pub fn from_env() -> Result<Self> {
        let runtime = match env::var_os("XDG_RUNTIME_DIR") {
            Some(v) if !v.is_empty() => PathBuf::from(v).join("vjproj"),
            _ => PathBuf::from("/tmp/vjproj"),
        };
        std::fs::create_dir_all(&runtime)
            .with_context(|| format!("cannot create {}", runtime.display()))?;
        Ok(Self { runtime })
    }

    pub fn state(&self) -> PathBuf {
        self.runtime.join("state.json")
    }

    pub fn lock(&self) -> PathBuf {
        self.runtime.join("state.lock")
    }

    pub fn watch_socket(&self) -> PathBuf {
        self.runtime.join("watch.sock")
    }
}
