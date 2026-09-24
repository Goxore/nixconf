use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Config {
    pub server_version: String,
    pub apk: PathBuf,
    pub apk_sha256: String,
    pub apk_package: String,
    pub hotspot_unit: String,
    pub hotspot_interface: String,
    pub hotspot_passphrase: PathBuf,
    pub wifi_interface: String,
    pub hostname: String,
    pub preview_command: PathBuf,
    pub desktop_command: PathBuf,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq)]
pub struct Software {
    pub package: String,
    pub version: String,
    pub version_code: u64,
    pub source: String,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq)]
pub struct Headset {
    pub serial: String,
    pub endpoint: String,
    pub model: String,
    pub transport: String,
    pub status: String,
    pub address: Option<String>,
    pub battery: Option<u8>,
    pub charging: bool,
    pub storage_available: Option<u64>,
    pub storage_total: Option<u64>,
    pub android: String,
    pub os_build: String,
    pub software: Vec<Software>,
    pub last_seen: u64,
    pub inventory_time: Option<u64>,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq)]
pub struct Runtime {
    pub available: bool,
    pub connected: bool,
    pub session_running: bool,
    pub headset_name: String,
    pub bitrate: u32,
    pub refresh_rate: f64,
    pub codecs: Vec<String>,
    pub pairing: bool,
    pub pin: String,
    pub version: Option<String>,
    pub configuration: serde_json::Value,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq)]
pub struct Hotspot {
    pub state: String,
    pub ready: bool,
    pub address: Option<String>,
    pub channel: Option<u32>,
    pub width: Option<u32>,
    pub ssid: Option<String>,
    pub passphrase: Option<String>,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq)]
pub struct Operation {
    pub id: u64,
    pub action: String,
    pub stage: String,
    pub running: bool,
    pub cancellable: bool,
    pub error: Option<String>,
    pub started: u64,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq)]
pub struct Preferences {
    #[serde(default)]
    pub auto_connect: bool,
    pub start_hotspot: bool,
    pub open_desktop: bool,
    pub headset_audio: bool,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq)]
pub struct Session {
    pub active: bool,
    pub started_hotspot: bool,
    pub started_server: bool,
    pub started_desktop: bool,
    pub audio_sink: Option<String>,
    pub audio_source: Option<String>,
    #[serde(default)]
    pub audio_routed: bool,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct Saved {
    pub selected: Option<String>,
    pub headsets: Vec<Headset>,
    pub wireless: Vec<Wireless>,
    pub preferences: Preferences,
    pub session: Session,
    #[serde(default)]
    pub interrupted: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Wireless {
    pub serial: String,
    pub address: String,
    pub mac: Option<String>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct State {
    pub revision: u64,
    pub configured_version: String,
    pub latest_version: Option<String>,
    pub latest_checked: Option<u64>,
    pub headsets: Vec<Headset>,
    pub selected: Option<String>,
    pub runtime: Runtime,
    pub hotspot: Hotspot,
    pub operation: Operation,
    pub preferences: Preferences,
    pub session: Session,
    pub problem: Option<String>,
    pub worn: Option<bool>,
}

impl State {
    pub fn new(config: &Config, saved: &Saved) -> Self {
        let mut headsets = saved.headsets.clone();
        for headset in &mut headsets {
            headset.status = "offline".into();
        }
        Self {
            revision: 0,
            configured_version: config.server_version.clone(),
            latest_version: None,
            latest_checked: None,
            headsets,
            selected: saved.selected.clone(),
            runtime: Runtime::default(),
            hotspot: Hotspot::default(),
            operation: Operation::default(),
            preferences: saved.preferences.clone(),
            session: saved.session.clone(),
            problem: saved.interrupted.then(|| "interrupted".into()),
            worn: None,
        }
    }

    pub fn headset(&self) -> Option<&Headset> {
        let serial = self.selected.as_ref()?;
        self.headsets.iter().find(|h| &h.serial == serial)
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(tag = "action", rename_all = "snake_case", deny_unknown_fields)]
pub enum Request {
    Status,
    Watch,
    Refresh,
    Select {
        serial: String,
    },
    Preferences {
        preferences: Preferences,
    },
    Hotspot {
        enabled: bool,
        #[serde(default)]
        confirm: bool,
    },
    Start,
    Stop,
    Cancel,
    Pair,
    EnableWireless,
    Install {
        #[serde(default)]
        confirm: bool,
    },
    Launch,
    Restart,
    Preview,
    Desktop,
    Audio {
        headset: bool,
    },
    Mute {
        muted: bool,
    },
    Updates,
    LaunchApp {
        package: String,
    },
    Forget {
        serial: String,
        #[serde(default)]
        confirm: bool,
    },
    Configure {
        encoder: String,
        codec: String,
    },
    Diagnostics,
}

impl Request {
    pub fn name(&self) -> String {
        serde_json::to_value(self).unwrap()["action"]
            .as_str()
            .unwrap()
            .to_string()
    }
}

pub fn now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

pub fn version(value: &str) -> Option<Vec<u32>> {
    let value = value.trim().trim_start_matches('v');
    let parts: Option<Vec<_>> = value.split('.').map(|v| v.parse().ok()).collect();
    parts.filter(|v| v.len() >= 2 && v.len() <= 3)
}

pub fn same_version(a: &str, b: &str) -> bool {
    match (version(a), version(b)) {
        (Some(a), Some(b)) => a == b,
        _ => false,
    }
}
