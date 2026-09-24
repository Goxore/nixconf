use anyhow::{Context, Result, bail};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct Dirs {
    pub runtime: PathBuf,
    pub data: PathBuf,
}

impl Dirs {
    pub fn from_env() -> Result<Self> {
        let runtime =
            vjcommon::xdg::dir("XDG_RUNTIME_DIR", "vjproj", || PathBuf::from("/tmp/vjproj"));
        let data = vjcommon::xdg::dir("XDG_DATA_HOME", "vjproj", || {
            home().join(".local/share/vjproj")
        });
        for dir in [&runtime, &data] {
            std::fs::create_dir_all(dir)
                .with_context(|| format!("cannot create {}", dir.display()))?;
        }
        Ok(Self { runtime, data })
    }

    pub fn state(&self) -> PathBuf {
        self.runtime.join("state.json")
    }

    pub fn lock(&self) -> PathBuf {
        self.runtime.join("state.lock")
    }

    pub fn agents(&self) -> PathBuf {
        self.runtime.join("agents")
    }

    pub fn status(&self) -> PathBuf {
        self.runtime.join("status")
    }

    pub fn projects(&self) -> PathBuf {
        self.data.join("projects.json")
    }

    pub fn token(&self) -> PathBuf {
        self.data.join("token")
    }

    pub fn push_key(&self) -> PathBuf {
        self.data.join("push.key")
    }

    pub fn subscriptions(&self) -> PathBuf {
        self.data.join("subscriptions.json")
    }

    pub fn batteries(&self) -> PathBuf {
        self.data.join("batteries.json")
    }

    pub fn devices(&self) -> PathBuf {
        self.data.join("devices.json")
    }
}

pub fn home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

pub fn rooted(dir: &Path) -> PathBuf {
    let home = home();
    match dir.strip_prefix("~") {
        Ok(rest) => home.join(rest),
        Err(_) => home.join(dir),
    }
}

pub fn home_dir(dir: &Path) -> Result<PathBuf> {
    let resolved = rooted(dir)
        .canonicalize()
        .ok()
        .filter(|resolved| resolved.is_dir())
        .with_context(|| format!("{} is not a directory", dir.display()))?;
    let home = home();
    let root = home.canonicalize().unwrap_or_else(|_| home.clone());
    if !resolved.starts_with(&root) {
        bail!("{} is outside {}", dir.display(), home.display());
    }
    Ok(resolved)
}
