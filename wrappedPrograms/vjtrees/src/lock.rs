use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Holder {
    pub pid: u32,
    pub command: String,
    pub started_at: u64,
}

fn held() -> &'static Mutex<HashMap<PathBuf, usize>> {
    static HELD: OnceLock<Mutex<HashMap<PathBuf, usize>>> = OnceLock::new();
    HELD.get_or_init(|| Mutex::new(HashMap::new()))
}

#[derive(Debug)]
pub struct Lock {
    path: PathBuf,
    owned: bool,
    released: bool,
}

pub fn is_alive(pid: u32) -> bool {
    Path::new(&format!("/proc/{pid}")).exists()
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn describe_age(started_at: u64) -> String {
    let seconds = now().saturating_sub(started_at);
    if seconds < 60 {
        format!("{seconds}s ago")
    } else if seconds < 3600 {
        format!("{}m ago", seconds / 60)
    } else {
        format!("{}h ago", seconds / 3600)
    }
}

impl Lock {
    pub fn acquire(path: &Path, command: &str) -> Result<Self> {
        let mut registry = held().lock().expect("lock registry poisoned");

        if let Some(depth) = registry.get_mut(path) {
            *depth += 1;
            return Ok(Self {
                path: path.to_path_buf(),
                owned: false,
                released: false,
            });
        }

        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("cannot create {}", parent.display()))?;
        }

        match create(path, command) {
            Ok(()) => {}
            Err(TryLock::Io(e)) => return Err(e),
            Err(TryLock::Held(holder)) => {
                if is_alive(holder.pid) {
                    bail!(
                        "another vjtrees is working in this project\n       \
                         `vjtrees {}` (pid {}) started {}\n       \
                         wait for it to finish — running two at once is what creates divergent changes",
                        holder.command,
                        holder.pid,
                        describe_age(holder.started_at)
                    );
                }

                eprintln!(
                    "  note: taking over a stale lock from `vjtrees {}` (pid {} is gone)",
                    holder.command, holder.pid
                );

                fs::remove_file(path)
                    .with_context(|| format!("cannot remove stale lock {}", path.display()))?;

                match create(path, command) {
                    Ok(()) => {}
                    Err(TryLock::Io(e)) => return Err(e),
                    Err(TryLock::Held(_)) => bail!(
                        "another vjtrees took the lock while we were clearing a stale one — try again"
                    ),
                }
            }
        }

        registry.insert(path.to_path_buf(), 1);

        Ok(Self {
            path: path.to_path_buf(),
            owned: true,
            released: false,
        })
    }

    pub fn release(&mut self) {
        if self.released {
            return;
        }
        self.released = true;

        let mut registry = held().lock().expect("lock registry poisoned");

        match registry.get_mut(&self.path) {
            Some(depth) if *depth > 1 => {
                *depth -= 1;
                return;
            }
            _ => {
                registry.remove(&self.path);
            }
        }

        if self.owned {
            let _ = fs::remove_file(&self.path);
        }
    }
}

impl Drop for Lock {
    fn drop(&mut self) {
        self.release();
    }
}

enum TryLock {
    Held(Holder),
    Io(anyhow::Error),
}

fn create(path: &Path, command: &str) -> std::result::Result<(), TryLock> {
    let holder = Holder {
        pid: std::process::id(),
        command: command.to_string(),
        started_at: now(),
    };

    let body = match toml::to_string(&holder) {
        Ok(body) => body,
        Err(e) => return Err(TryLock::Io(anyhow::anyhow!(e))),
    };

    match fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)
    {
        Ok(mut file) => match file.write_all(body.as_bytes()) {
            Ok(()) => Ok(()),
            Err(e) => {
                let _ = fs::remove_file(path);
                Err(TryLock::Io(
                    anyhow::Error::from(e).context(format!("cannot write lock {}", path.display())),
                ))
            }
        },
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
            Err(TryLock::Held(read_holder(path)))
        }
        Err(e) => Err(TryLock::Io(
            anyhow::Error::from(e).context(format!("cannot create lock {}", path.display())),
        )),
    }
}

fn read_holder(path: &Path) -> Holder {
    fs::read_to_string(path)
        .ok()
        .and_then(|text| toml::from_str(&text).ok())
        .unwrap_or(Holder {
            pid: 0,
            command: "unknown".to_string(),
            started_at: 0,
        })
}
