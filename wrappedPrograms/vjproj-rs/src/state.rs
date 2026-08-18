use crate::paths::Dirs;
use anyhow::{Context, Result};
use fs2::FileExt;
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::Path;

const MRU_CAP: usize = 8;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct State {
    pub active: u8,
    #[serde(default)]
    pub mru: VecDeque<u8>,
}

impl Default for State {
    fn default() -> Self {
        Self {
            active: 1,
            mru: VecDeque::new(),
        }
    }
}

impl State {
    pub fn record_switch(&mut self, from: u8, to: u8) {
        if from == to {
            return;
        }
        self.mru.retain(|&p| p != from);
        self.mru.push_front(from);
        while self.mru.len() > MRU_CAP {
            self.mru.pop_back();
        }
        self.mru.retain(|&p| p != to);
        self.active = to;
    }

    pub fn mru_next(&self) -> Option<u8> {
        self.mru.front().copied().filter(|&p| p != self.active)
    }
}

pub fn load(dirs: &Dirs) -> Result<State> {
    let path = dirs.state();
    match std::fs::read_to_string(&path) {
        Ok(s) if s.trim().is_empty() => Ok(State::default()),
        Ok(s) => {
            serde_json::from_str(&s).with_context(|| format!("cannot parse {}", path.display()))
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(State::default()),
        Err(e) => Err(e).with_context(|| format!("cannot read {}", path.display())),
    }
}

pub fn save(dirs: &Dirs, state: &State) -> Result<()> {
    let path = dirs.state();
    let parent = path.parent().unwrap_or(Path::new("."));
    std::fs::create_dir_all(parent)
        .with_context(|| format!("cannot create {}", parent.display()))?;
    let body = serde_json::to_string(state).context("cannot serialize state")?;
    let tmp = path.with_extension("json.tmp");
    {
        let mut f =
            File::create(&tmp).with_context(|| format!("cannot create {}", tmp.display()))?;
        f.write_all(body.as_bytes())?;
        f.sync_all()?;
    }
    std::fs::rename(&tmp, &path).with_context(|| format!("cannot replace {}", path.display()))?;
    Ok(())
}

pub struct Guard {
    file: File,
}

impl Guard {
    pub fn acquire(dirs: &Dirs) -> Result<Self> {
        let path = dirs.lock();
        let file = OpenOptions::new()
            .create(true)
            .read(true)
            .write(true)
            .truncate(false)
            .open(&path)
            .with_context(|| format!("cannot open {}", path.display()))?;
        file.lock_exclusive()
            .with_context(|| format!("cannot lock {}", path.display()))?;
        Ok(Self { file })
    }
}

impl Drop for Guard {
    fn drop(&mut self) {
        let _ = FileExt::unlock(&self.file);
    }
}
