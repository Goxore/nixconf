use crate::paths::atomic_write;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

pub const ENV_ALLOW: &str = "allow";
pub const ENV_DENY: &str = "deny";

#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Entry {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub identity: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub env: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub shell: Option<String>,
    #[serde(flatten, default, skip_serializing_if = "BTreeMap::is_empty")]
    pub tools: BTreeMap<String, String>,
}

impl Entry {
    pub fn tool(&self, tool: &str) -> Option<&str> {
        self.tools.get(tool).map(String::as_str)
    }
}

#[derive(Debug, Default, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Registry {
    pub entries: BTreeMap<String, Entry>,
}

fn key(root: &Path) -> String {
    root.to_string_lossy().into_owned()
}

impl Registry {
    pub fn parse(text: &str) -> Result<Self> {
        Ok(toml::from_str(text)?)
    }

    pub fn render(&self) -> Result<String> {
        Ok(toml::to_string_pretty(self)?)
    }

    pub fn load(path: &Path) -> Result<Self> {
        match fs::read_to_string(path) {
            Ok(text) => {
                Self::parse(&text).with_context(|| format!("cannot parse {}", path.display()))
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Self::default()),
            Err(e) => Err(anyhow::Error::from(e)
                .context(format!("cannot read {}", path.display()))),
        }
    }

    pub fn get(&self, root: &Path) -> Option<&Entry> {
        self.entries.get(&key(root))
    }

    pub fn entry_mut(&mut self, root: &Path) -> &mut Entry {
        self.entries.entry(key(root)).or_default()
    }

    pub fn update<T>(path: &Path, f: impl FnOnce(&mut Self) -> Result<T>) -> Result<T> {
        let parent = path.parent().unwrap_or(Path::new("."));
        fs::create_dir_all(parent)
            .with_context(|| format!("cannot create {}", parent.display()))?;

        let lock_path = with_suffix(path, ".lock");
        let lock = fs::OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .open(&lock_path)
            .with_context(|| format!("cannot open {}", lock_path.display()))?;
        lock.lock()
            .with_context(|| format!("cannot lock {}", lock_path.display()))?;

        let result = (|| {
            let mut reg = Self::load(path)?;
            let out = f(&mut reg)?;
            atomic_write(path, reg.render()?.as_bytes())?;
            Ok(out)
        })();

        let _ = lock.unlock();
        result
    }
}

fn with_suffix(path: &Path, suffix: &str) -> PathBuf {
    let mut s = path.as_os_str().to_os_string();
    s.push(suffix);
    PathBuf::from(s)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_all_fields() {
        let text = r#"
            ["/home/yurii/Projects/secretspec"]
            identity = "vimjoyer"
            env = "allow"
            claude = "main"
            codex = "main"
        "#;
        let reg = Registry::parse(text).unwrap();
        let e = reg.get(Path::new("/home/yurii/Projects/secretspec")).unwrap();
        assert_eq!(e.identity.as_deref(), Some("vimjoyer"));
        assert_eq!(e.env.as_deref(), Some(ENV_ALLOW));
        assert_eq!(e.tool("claude"), Some("main"));
        assert_eq!(e.tool("codex"), Some("main"));
        assert_eq!(e.tool("nope"), None);

        let reparsed = Registry::parse(&reg.render().unwrap()).unwrap();
        assert_eq!(reg, reparsed);
    }

    #[test]
    fn missing_file_is_an_empty_registry() {
        let tmp = tempfile::tempdir().unwrap();
        let reg = Registry::load(&tmp.path().join("nope.toml")).unwrap();
        assert!(reg.entries.is_empty());
    }

    #[test]
    fn paths_with_awkward_characters_survive_a_round_trip() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("projects.toml");
        let weird = Path::new("/home/yurii/Projects/it's \"quoted\" \\ odd");

        Registry::update(&path, |r| {
            r.entry_mut(weird).identity = Some("goxore".into());
            Ok(())
        })
        .unwrap();

        let reg = Registry::load(&path).unwrap();
        assert_eq!(reg.get(weird).unwrap().identity.as_deref(), Some("goxore"));
    }

    #[test]
    fn update_is_atomic_and_leaves_no_temp_files() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("projects.toml");

        Registry::update(&path, |r| {
            r.entry_mut(Path::new("/a")).identity = Some("goxore".into());
            Ok(())
        })
        .unwrap();
        Registry::update(&path, |r| {
            r.entry_mut(Path::new("/b")).env = Some(ENV_DENY.into());
            Ok(())
        })
        .unwrap();

        let reg = Registry::load(&path).unwrap();
        assert_eq!(reg.entries.len(), 2);

        let stray: Vec<_> = fs::read_dir(tmp.path())
            .unwrap()
            .map(|e| e.unwrap().file_name().to_string_lossy().into_owned())
            .filter(|n| n.contains(".tmp."))
            .collect();
        assert!(stray.is_empty(), "temp files left behind: {stray:?}");
    }

    #[test]
    fn a_failing_update_does_not_touch_the_file() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("projects.toml");
        Registry::update(&path, |r| {
            r.entry_mut(Path::new("/a")).identity = Some("goxore".into());
            Ok(())
        })
        .unwrap();
        let before = fs::read_to_string(&path).unwrap();

        let err = Registry::update(&path, |r| -> Result<()> {
            r.entry_mut(Path::new("/b")).identity = Some("wrong".into());
            anyhow::bail!("simulated failure")
        });
        assert!(err.is_err());
        assert_eq!(fs::read_to_string(&path).unwrap(), before);
    }

    #[test]
    fn concurrent_updates_all_survive() {
        let tmp = tempfile::tempdir().unwrap();
        let path = tmp.path().join("projects.toml");
        const N: usize = 16;

        std::thread::scope(|s| {
            for i in 0..N {
                let path = path.clone();
                s.spawn(move || {
                    Registry::update(&path, |r| {
                        r.entry_mut(Path::new(&format!("/p/{i}"))).identity =
                            Some(format!("id{i}"));
                        Ok(())
                    })
                    .unwrap();
                });
            }
        });

        let reg = Registry::load(&path).unwrap();
        assert_eq!(reg.entries.len(), N, "lost writes: {:?}", reg.entries.keys());
        for i in 0..N {
            let e = reg.get(Path::new(&format!("/p/{i}"))).unwrap();
            assert_eq!(e.identity.as_deref(), Some(format!("id{i}").as_str()));
        }
    }
}
