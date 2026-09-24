use crate::held;
use crate::paths::Dirs;
use crate::peers::PeerView;
use crate::tailnet::{self, Sighting};
use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const REFRESH: Duration = Duration::from_secs(5);

const SYSTEM: &str = "/etc/vjproj/system.json";

const WIVRN: &str = "org.meumeu.wivrn";

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Kind {
    #[default]
    Computer,
    Phone,
    Headset,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct System {
    pub release: String,
    pub revision: Option<String>,
    pub built: Option<u64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Charge {
    pub level: u8,
    pub at: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Battery {
    pub level: u8,
    pub charging: bool,
    pub at: u64,
    #[serde(default)]
    pub since: Option<Charge>,
    #[serde(default)]
    pub full_at: Option<u64>,
}

impl Battery {
    pub fn reported(previous: Option<&Battery>, level: u8, charging: bool, now: u64) -> Self {
        let since = match previous {
            _ if !charging => None,
            Some(previous) if previous.charging => previous.since.or(Some(Charge {
                level: previous.level,
                at: previous.at,
            })),
            _ => Some(Charge { level, at: now }),
        };
        let mut battery = Self {
            level,
            charging,
            at: now,
            since,
            full_at: None,
        };
        battery.full_at = battery.estimated();
        battery
    }

    pub fn estimated(&self) -> Option<u64> {
        let since = self.since.filter(|_| self.charging && self.level < 100)?;
        let gained = u64::from(
            self.level
                .checked_sub(since.level)
                .filter(|&gain| gain > 0)?,
        );
        let elapsed = self.at.checked_sub(since.at).filter(|&time| time > 0)?;
        Some(self.at + u64::from(100 - self.level) * elapsed / gained)
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Device {
    pub id: String,
    pub name: String,
    pub kind: Kind,
    pub here: bool,
    pub online: bool,
    pub seen: Option<u64>,
    pub system: Option<System>,
    pub battery: Option<Battery>,
    pub android: Option<String>,
    pub wivrn: Option<String>,
}

pub fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.as_secs())
        .unwrap_or(0)
}

pub fn kind_of(os: &str) -> Kind {
    match os.to_ascii_lowercase().as_str() {
        "android" | "ios" => Kind::Phone,
        _ => Kind::Computer,
    }
}

pub fn parse_system(raw: &str) -> Option<System> {
    serde_json::from_str(raw)
        .ok()
        .filter(|system: &System| !system.release.is_empty())
}

pub fn parse_headset(raw: &str) -> Option<Device> {
    let state: Value = serde_json::from_str(raw).ok()?;
    let headsets = state["headsets"].as_array()?;
    let selected = state["selected"].as_str();
    let headset = headsets
        .iter()
        .find(|headset| selected.is_some() && headset["serial"].as_str() == selected)
        .or_else(|| headsets.first())?;
    let serial = headset["serial"]
        .as_str()
        .filter(|serial| !serial.is_empty())?;
    let seen = headset["last_seen"].as_u64().filter(|&seen| seen > 0);
    let battery = headset["battery"]
        .as_u64()
        .and_then(|level| u8::try_from(level).ok())
        .map(|level| Battery {
            level,
            charging: headset["charging"].as_bool().unwrap_or(false),
            at: seen.unwrap_or(0),
            since: None,
            full_at: None,
        });
    let wivrn = headset["software"].as_array().and_then(|software| {
        software
            .iter()
            .find(|app| {
                app["package"]
                    .as_str()
                    .is_some_and(|package| package.starts_with(WIVRN))
            })
            .and_then(|app| app["version"].as_str())
            .map(str::to_owned)
    });
    Some(Device {
        id: format!("headset-{serial}"),
        name: headset["model"].as_str().unwrap_or(serial).to_owned(),
        kind: Kind::Headset,
        here: false,
        online: headset["status"].as_str() == Some("device"),
        seen,
        system: None,
        battery,
        android: headset["android"]
            .as_str()
            .filter(|android| !android.is_empty())
            .map(str::to_owned),
        wivrn,
    })
}

pub fn load_batteries(dirs: &Dirs) -> HashMap<String, Battery> {
    std::fs::read_to_string(dirs.batteries())
        .ok()
        .and_then(|raw| serde_json::from_str(&raw).ok())
        .unwrap_or_default()
}

pub fn valid_level(level: u8) -> Result<u8> {
    if level > 100 {
        bail!("battery level must be between 0 and 100");
    }
    Ok(level)
}

pub fn report(dirs: &Dirs, id: &str, level: u8, charging: bool, now: u64) -> Result<Battery> {
    let level = valid_level(level)?;
    let _guard = crate::state::Guard::acquire(dirs)?;
    let mut batteries = load_batteries(dirs);
    let battery = Battery::reported(batteries.get(id), level, charging, now);
    batteries.insert(id.to_owned(), battery.clone());
    let body = serde_json::to_string(&batteries).context("cannot serialize batteries")?;
    vjcommon::atomic::write(&dirs.batteries(), body.as_bytes())?;
    Ok(battery)
}

pub fn load_remembered(dirs: &Dirs) -> Vec<Device> {
    std::fs::read_to_string(dirs.devices())
        .ok()
        .and_then(|raw| serde_json::from_str(&raw).ok())
        .unwrap_or_default()
}

pub fn memorable(devices: &[Device]) -> Vec<Device> {
    devices
        .iter()
        .filter(|device| {
            device.system.is_some() || device.battery.is_some() || device.kind == Kind::Headset
        })
        .cloned()
        .collect()
}

fn remember(dirs: &Dirs, devices: &[Device]) -> Result<()> {
    let body = serde_json::to_string(devices).context("cannot serialize devices")?;
    vjcommon::atomic::write(&dirs.devices(), body.as_bytes())
}

pub fn told_by(peers: &[PeerView]) -> Vec<Device> {
    peers
        .iter()
        .filter_map(|peer| {
            serde_json::from_value::<Vec<Device>>(peer.state["devices"].clone()).ok()
        })
        .flatten()
        .collect()
}

fn newer(current: Option<Battery>, candidate: Option<&Battery>) -> Option<Battery> {
    match (current, candidate) {
        (Some(current), Some(candidate)) if candidate.at > current.at => Some(candidate.clone()),
        (None, Some(candidate)) => Some(candidate.clone()),
        (current, _) => current,
    }
}

fn from_sighting(sighting: &Sighting) -> Device {
    Device {
        id: sighting.id.clone(),
        name: sighting.name.clone(),
        kind: kind_of(&sighting.os),
        here: sighting.here,
        online: sighting.online,
        seen: if sighting.online { None } else { sighting.seen },
        ..Device::default()
    }
}

pub struct Known<'a> {
    pub sightings: &'a [Sighting],
    pub machines: &'a [String],
    pub system: Option<System>,
    pub headset: Option<Device>,
    pub batteries: &'a HashMap<String, Battery>,
    pub told: &'a [Device],
    pub remembered: &'a [Device],
}

pub fn assemble(known: &Known) -> Vec<Device> {
    let mut devices: Vec<Device> = known.sightings.iter().map(from_sighting).collect();
    for machine in known.machines {
        if !devices.iter().any(|device| &device.id == machine) {
            devices.push(Device {
                id: machine.clone(),
                name: machine.clone(),
                ..Device::default()
            });
        }
    }

    for device in &mut devices {
        device.system = if device.here {
            known.system.clone()
        } else {
            known
                .told
                .iter()
                .find(|told| told.here && told.id == device.id)
                .or_else(|| known.remembered.iter().find(|old| old.id == device.id))
                .and_then(|source| source.system.clone())
        };
        if device.kind == Kind::Phone {
            let mut battery = known.batteries.get(&device.id).cloned();
            for told in known
                .told
                .iter()
                .chain(known.remembered)
                .filter(|told| told.id == device.id)
            {
                battery = newer(battery, told.battery.as_ref());
            }
            device.battery = battery;
        }
    }

    let headsets = known
        .headset
        .iter()
        .chain(known.told.iter().filter(|told| told.kind == Kind::Headset))
        .cloned()
        .chain(
            known
                .remembered
                .iter()
                .filter(|old| old.kind == Kind::Headset)
                .map(|old| Device {
                    online: false,
                    ..old.clone()
                }),
        );
    for headset in headsets {
        match devices.iter_mut().find(|device| device.id == headset.id) {
            Some(device) if headset.online && !device.online => *device = headset,
            Some(device) if !device.online && headset.seen > device.seen => *device = headset,
            Some(_) => {}
            None => devices.push(headset),
        }
    }

    devices.sort_by(|a, b| {
        (!a.here, a.kind, a.name.to_lowercase()).cmp(&(!b.here, b.kind, b.name.to_lowercase()))
    });
    devices
}

fn run(program: &str, args: &[&str]) -> Option<String> {
    let out = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    out.status
        .success()
        .then(|| String::from_utf8_lossy(&out.stdout).into_owned())
}

fn local_system(path: &Path) -> Option<System> {
    parse_system(&std::fs::read_to_string(path).ok()?)
}

pub fn gather(dirs: &Dirs, machines: &[String], peers: &[PeerView]) -> Vec<Device> {
    let remembered = load_remembered(dirs);
    let devices = assemble(&Known {
        sightings: &tailnet::sightings(),
        machines,
        system: local_system(Path::new(SYSTEM)),
        headset: run("vjvr", &["status"]).and_then(|raw| parse_headset(&raw)),
        batteries: &load_batteries(dirs),
        told: &told_by(peers),
        remembered: &remembered,
    });
    let memorable = memorable(&devices);
    if memorable != remembered {
        let _ = remember(dirs, &memorable);
    }
    devices
}

pub fn watch(
    dirs: &Dirs,
    machines: Vec<String>,
    peers: Arc<Mutex<Vec<PeerView>>>,
) -> Arc<Mutex<Vec<Device>>> {
    let cell: Arc<Mutex<Vec<Device>>> = Arc::new(Mutex::new(Vec::new()));
    let into = Arc::clone(&cell);
    let dirs = dirs.clone();
    thread::spawn(move || {
        loop {
            let known = held(&peers).clone();
            let found = gather(&dirs, &machines, &known);
            *held(&into) = found;
            thread::sleep(REFRESH);
        }
    });
    cell
}
