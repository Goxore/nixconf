use crate::held;
use crate::tailnet::{self, Peer};
use serde_json::Value;
use std::net::Ipv4Addr;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

const REFRESH: Duration = Duration::from_secs(2);

const TIMEOUT: &str = "2";

const NAMED: &str = "VJPROJ_MACHINES";

pub fn parse_machines(raw: &str) -> Vec<String> {
    raw.split(',')
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .map(str::to_owned)
        .collect()
}

pub fn machines(given: Vec<String>) -> Vec<String> {
    if !given.is_empty() {
        return given;
    }
    std::env::var(NAMED)
        .map(|raw| parse_machines(&raw))
        .unwrap_or_default()
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct PeerView {
    pub host: String,
    pub address: String,
    pub state: Value,
}

pub fn endpoint(address: Ipv4Addr, port: u16, path: &str) -> String {
    format!("http://{address}:{port}{path}")
}

fn get(url: &str) -> Option<String> {
    let out = Command::new("curl")
        .args(["--silent", "--show-error", "--fail", "--max-time", TIMEOUT])
        .arg(url)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .ok()?;
    out.status
        .success()
        .then(|| String::from_utf8_lossy(&out.stdout).into_owned())
}

pub fn forward(
    address: Ipv4Addr,
    port: u16,
    method: &str,
    path: &str,
    body: &str,
) -> Option<Value> {
    let url = endpoint(address, port, path);
    let mut command = Command::new("curl");
    command.args(["--silent", "--show-error", "--fail", "--max-time", TIMEOUT]);
    command.args(["--request", method]);
    command.args(["--header", &format!("{}: 1", crate::http::FORWARDED)]);
    if method != "GET" {
        command.args(["--header", "Content-Type: application/json"]);
        command.args(["--data-binary", body]);
    }
    let out = command
        .arg(&url)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    serde_json::from_slice(&out.stdout).ok()
}

fn reach(peer: &Peer, port: u16) -> Option<PeerView> {
    let raw = get(&endpoint(peer.address, port, "/state"))?;
    let state = serde_json::from_str(&raw).ok()?;
    Some(PeerView {
        host: peer.host.clone(),
        address: peer.address.to_string(),
        state,
    })
}

pub fn watch(port: u16, allowed: Vec<String>) -> Arc<Mutex<Vec<PeerView>>> {
    let cell: Arc<Mutex<Vec<PeerView>>> = Arc::new(Mutex::new(Vec::new()));
    if allowed.is_empty() {
        return cell;
    }
    let into = Arc::clone(&cell);
    thread::spawn(move || {
        loop {
            let found: Vec<PeerView> = tailnet::peers(&allowed)
                .iter()
                .filter_map(|peer| reach(peer, port))
                .collect();
            *held(&into) = found;
            thread::sleep(REFRESH);
        }
    });
    cell
}

pub fn here() -> String {
    std::fs::read_to_string("/proc/sys/kernel/hostname")
        .map(|raw| raw.trim().to_owned())
        .unwrap_or_default()
}

pub fn located(known: &[PeerView], host: &str) -> Option<Ipv4Addr> {
    known
        .iter()
        .find(|peer| peer.host == host)
        .and_then(|peer| peer.address.parse().ok())
}
