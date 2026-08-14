use crate::config::{Config, MARKER};
use anyhow::{Context, Result, bail};
use std::fs;
use std::path::{Path, PathBuf};

pub const STATE_DIR: &str = ".vjtrees";

#[derive(Debug, Clone)]
pub struct Root {
    pub root: PathBuf,
    pub trunk: PathBuf,
    pub config: Config,
}

impl Root {
    pub fn find(start: &Path) -> Result<Self> {
        let marker = find_marker(start).with_context(|| {
            format!(
                "no {MARKER} found from {} — vjtrees needs a project root\n       \
                 create one with: vjtrees init",
                start.display()
            )
        })?;

        let root = marker
            .parent()
            .expect("marker always has a parent")
            .to_path_buf();

        let text = fs::read_to_string(&marker)
            .with_context(|| format!("cannot read {}", marker.display()))?;

        let config = Config::parse(&text)
            .with_context(|| format!("invalid config in {}", marker.display()))?;

        let trunk = root.join(&config.project.trunk);
        if !trunk.join(".jj").exists() {
            bail!(
                "{} says the trunk is {:?}, but {} is not a jj repository",
                marker.display(),
                config.project.trunk,
                trunk.display()
            );
        }

        Ok(Self {
            root,
            trunk,
            config,
        })
    }

    pub fn trunk_workspace(&self) -> &str {
        &self.config.project.trunk_workspace
    }

    pub fn trunk_dir_name(&self) -> &str {
        &self.config.project.trunk
    }

    pub fn dir_name_of(&self, jj_name: &str) -> String {
        if jj_name == self.trunk_workspace() {
            self.trunk_dir_name().to_string()
        } else {
            jj_name.to_string()
        }
    }

    pub fn jj_name_of(&self, dir_name: &str) -> String {
        if dir_name == self.trunk_dir_name() {
            self.trunk_workspace().to_string()
        } else {
            dir_name.to_string()
        }
    }

    pub fn workspace_path(&self, dir_name: &str) -> PathBuf {
        self.root.join(dir_name)
    }

    pub fn state_dir(&self) -> PathBuf {
        self.root.join(STATE_DIR)
    }

    pub fn lock_path(&self) -> PathBuf {
        self.state_dir().join("lock")
    }

    pub fn state_path(&self) -> PathBuf {
        self.state_dir().join("state.json")
    }

    pub fn workspace_dirs(&self) -> Result<Vec<String>> {
        let mut names = Vec::new();

        for entry in fs::read_dir(&self.root)
            .with_context(|| format!("cannot list {}", self.root.display()))?
        {
            let entry = entry?;
            let name = entry.file_name().to_string_lossy().to_string();
            if self.root.join(&name).join(".jj").exists() {
                names.push(name);
            }
        }

        names.sort();
        Ok(names)
    }

    pub fn is_own_jj_repo(&self, dir_name: &str) -> bool {
        if dir_name == self.trunk_dir_name() {
            return false;
        }
        self.workspace_path(dir_name)
            .join(".jj")
            .join("repo")
            .is_dir()
    }
}

fn find_marker(start: &Path) -> Option<PathBuf> {
    let mut dir = Some(start);

    while let Some(current) = dir {
        let candidate = current.join(MARKER);
        if candidate.exists() {
            return Some(candidate);
        }
        dir = current.parent();
    }

    None
}
