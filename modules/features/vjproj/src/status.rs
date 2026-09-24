use crate::paths::Dirs;
use serde_json::Value;
use std::fs;
use std::path::PathBuf;

fn path_for(dirs: &Dirs, pid: u32) -> PathBuf {
    dirs.status().join(format!("{pid}.json"))
}

pub fn load(dirs: &Dirs, pid: u32) -> Option<Value> {
    let raw = fs::read_to_string(path_for(dirs, pid)).ok()?;
    serde_json::from_str(&raw).ok()
}

pub fn forget(dirs: &Dirs, pid: u32) {
    let _ = fs::remove_file(path_for(dirs, pid));
}
