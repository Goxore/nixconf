use crate::paths::Dirs;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::Path;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Profile {
    pub id: u32,
    pub name: String,
    #[serde(default)]
    pub icon: String,
    #[serde(default)]
    pub dir: String,
    #[serde(default)]
    pub used: u128,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Library {
    #[serde(default)]
    pub slots: BTreeMap<u8, u32>,
    #[serde(default)]
    pub profiles: Vec<Profile>,
}

pub fn deserted(occupied: bool, agents: usize) -> bool {
    !occupied && agents == 0
}

pub fn blank(named: bool, occupied: bool, agents: usize) -> bool {
    !named && deserted(occupied, agents)
}

pub fn named_after(dir: &str) -> String {
    Path::new(dir)
        .file_name()
        .map(|base| base.to_string_lossy().into_owned())
        .unwrap_or_else(|| dir.to_owned())
}

impl Library {
    pub fn get(&self, id: u32) -> Option<&Profile> {
        self.profiles.iter().find(|profile| profile.id == id)
    }

    pub fn at(&self, slot: u8) -> Option<&Profile> {
        self.get(*self.slots.get(&slot)?)
    }

    pub fn slot_of(&self, id: u32) -> Option<u8> {
        self.slots
            .iter()
            .find(|(_, held)| **held == id)
            .map(|(slot, _)| *slot)
    }

    pub fn shelved(&self) -> Vec<&Profile> {
        let mut free: Vec<&Profile> = self
            .profiles
            .iter()
            .filter(|profile| self.slot_of(profile.id).is_none())
            .collect();
        free.sort_by(|a, b| b.used.cmp(&a.used).then_with(|| a.name.cmp(&b.name)));
        free
    }

    pub fn create(&mut self, name: String, icon: String, dir: String, now: u128) -> u32 {
        let id = self.profiles.iter().map(|p| p.id).max().unwrap_or(0) + 1;
        self.profiles.push(Profile {
            id,
            name,
            icon,
            dir,
            used: now,
        });
        id
    }

    pub fn assign(&mut self, slot: u8, id: u32, now: u128) {
        self.slots.retain(|_, held| *held != id);
        self.slots.insert(slot, id);
        self.touch(slot, now);
    }

    pub fn clear(&mut self, slot: u8) {
        self.slots.remove(&slot);
    }

    pub fn swap(&mut self, a: u8, b: u8) {
        let left = self.slots.remove(&a);
        let right = self.slots.remove(&b);
        if let Some(id) = left {
            self.slots.insert(b, id);
        }
        if let Some(id) = right {
            self.slots.insert(a, id);
        }
    }

    pub fn describe(
        &mut self,
        slot: u8,
        name: Option<String>,
        icon: Option<String>,
        dir: Option<String>,
        now: u128,
    ) {
        let id = match self.slots.get(&slot) {
            Some(id) => *id,
            None => {
                let fresh = self.create(String::new(), String::new(), String::new(), now);
                self.slots.insert(slot, fresh);
                fresh
            }
        };
        let Some(profile) = self.profiles.iter_mut().find(|p| p.id == id) else {
            return;
        };
        if let Some(name) = name {
            profile.name = name;
        }
        if let Some(icon) = icon {
            profile.icon = icon;
        }
        if let Some(dir) = dir {
            profile.dir = dir;
        }
    }

    pub fn adopt(&mut self, slot: u8, dir: &str, now: u128) -> bool {
        if dir.is_empty() || self.slots.contains_key(&slot) {
            return false;
        }
        let known = self
            .profiles
            .iter()
            .find(|profile| profile.dir == dir && self.slot_of(profile.id).is_none())
            .map(|profile| profile.id);
        let id = match known {
            Some(id) => id,
            None => self.create(named_after(dir), String::new(), dir.to_owned(), now),
        };
        self.assign(slot, id, now);
        true
    }

    pub fn remember_dir(&mut self, slot: u8, dir: &str) -> bool {
        if dir.is_empty() {
            return false;
        }
        let Some(id) = self.slots.get(&slot).copied() else {
            return false;
        };
        let Some(profile) = self.profiles.iter_mut().find(|p| p.id == id) else {
            return false;
        };
        if !profile.dir.is_empty() {
            return false;
        }
        profile.dir = dir.to_owned();
        true
    }

    pub fn forget(&mut self, id: u32) {
        self.slots.retain(|_, held| *held != id);
        self.profiles.retain(|profile| profile.id != id);
    }

    pub fn touch(&mut self, slot: u8, now: u128) {
        let Some(id) = self.slots.get(&slot).copied() else {
            return;
        };
        if let Some(profile) = self.profiles.iter_mut().find(|p| p.id == id) {
            profile.used = now;
        }
    }
}

pub fn load(dirs: &Dirs) -> Result<Library> {
    let path = dirs.projects();
    match std::fs::read_to_string(&path) {
        Ok(raw) if raw.trim().is_empty() => Ok(Library::default()),
        Ok(raw) => {
            serde_json::from_str(&raw).with_context(|| format!("cannot parse {}", path.display()))
        }
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Library::default()),
        Err(e) => Err(e).with_context(|| format!("cannot read {}", path.display())),
    }
}

pub fn save(dirs: &Dirs, library: &Library) -> Result<()> {
    let body = serde_json::to_string(library).context("cannot serialize projects")?;
    vjcommon::atomic::write(&dirs.projects(), body.as_bytes())
}
