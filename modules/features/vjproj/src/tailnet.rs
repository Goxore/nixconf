use anyhow::{Context, Result, bail};
use serde::Deserialize;
use std::collections::HashMap;
use std::net::Ipv4Addr;
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

const RETRY: Duration = Duration::from_secs(3);

pub fn is_tailnet(address: Ipv4Addr) -> bool {
    let [first, second, ..] = address.octets();
    first == 100 && (64..128).contains(&second)
}

pub fn parse_address(raw: &str) -> Option<Ipv4Addr> {
    raw.lines()
        .filter_map(|line| line.trim().parse().ok())
        .find(|&address| is_tailnet(address))
}

pub fn address() -> Result<Ipv4Addr> {
    let out = Command::new("tailscale")
        .args(["ip", "-4"])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .context("cannot run tailscale")?;
    if !out.status.success() {
        bail!(
            "tailscale ip -4 failed: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        );
    }
    match parse_address(&String::from_utf8_lossy(&out.stdout)) {
        Some(address) => Ok(address),
        None => bail!("tailscale reported no address on the tailnet"),
    }
}

pub fn wait() -> Ipv4Addr {
    loop {
        match address() {
            Ok(address) => return address,
            Err(_) => thread::sleep(RETRY),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Peer {
    pub host: String,
    pub address: Ipv4Addr,
}

#[derive(Deserialize)]
struct Profile {
    #[serde(rename = "LoginName", default)]
    login: String,
}

#[derive(Deserialize)]
struct Node {
    #[serde(rename = "HostName", default)]
    host: String,
    #[serde(rename = "DNSName", default)]
    dns: String,
    #[serde(rename = "TailscaleIPs", default)]
    addresses: Vec<String>,
    #[serde(rename = "UserID", default)]
    user: u64,
    #[serde(rename = "Online", default)]
    online: bool,
    #[serde(rename = "OS", default)]
    os: String,
    #[serde(rename = "LastSeen", default)]
    last_seen: String,
}

#[derive(Deserialize)]
struct Status {
    #[serde(rename = "Self")]
    own: Node,
    #[serde(rename = "Peer", default)]
    peers: HashMap<String, Node>,
    #[serde(rename = "User", default)]
    users: HashMap<String, Profile>,
}

#[derive(Deserialize)]
struct Named {
    #[serde(rename = "Name", default)]
    name: String,
}

#[derive(Deserialize)]
struct Whois {
    #[serde(rename = "UserProfile")]
    profile: Profile,
    #[serde(rename = "Node")]
    node: Named,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Identity {
    pub login: String,
    pub host: String,
}

pub fn label(dns: &str, host: &str) -> String {
    let first = dns.trim_end_matches('.').split('.').next().unwrap_or("");
    if first.is_empty() {
        host.to_owned()
    } else {
        first.to_owned()
    }
}

fn own_address(node: &Node) -> Option<Ipv4Addr> {
    node.addresses
        .iter()
        .filter_map(|raw| raw.parse().ok())
        .find(|&address| is_tailnet(address))
}

pub fn parse_peers(raw: &str, allowed: &[String]) -> Vec<Peer> {
    let Ok(status) = serde_json::from_str::<Status>(raw) else {
        return Vec::new();
    };
    let mut found: Vec<Peer> = status
        .peers
        .values()
        .filter(|node| node.online && node.user == status.own.user)
        .filter_map(|node| {
            Some(Peer {
                host: label(&node.dns, &node.host),
                address: own_address(node)?,
            })
        })
        .filter(|peer| allowed.contains(&peer.host))
        .collect();
    found.sort_by(|a, b| a.host.cmp(&b.host));
    found
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Sighting {
    pub id: String,
    pub name: String,
    pub os: String,
    pub online: bool,
    pub seen: Option<u64>,
    pub here: bool,
}

fn sighted(node: &Node, here: bool) -> Sighting {
    Sighting {
        id: label(&node.dns, &node.host),
        name: if node.host.is_empty() {
            label(&node.dns, "")
        } else {
            node.host.clone()
        },
        os: node.os.clone(),
        online: here || node.online,
        seen: unix_seconds(&node.last_seen),
        here,
    }
}

pub fn parse_sightings(raw: &str) -> Vec<Sighting> {
    let Ok(status) = serde_json::from_str::<Status>(raw) else {
        return Vec::new();
    };
    let mut found: Vec<Sighting> = status
        .peers
        .values()
        .filter(|node| node.user == status.own.user)
        .map(|node| sighted(node, false))
        .collect();
    found.push(sighted(&status.own, true));
    found.sort_by(|a, b| a.id.cmp(&b.id));
    found
}

fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = year.div_euclid(400);
    let of_era = year - era * 400;
    let shifted = (month + 9) % 12;
    let of_year = (153 * shifted + 2) / 5 + day - 1;
    let of_cycle = of_era * 365 + of_era / 4 - of_era / 100 + of_year;
    era * 146_097 + of_cycle - 719_468
}

pub fn unix_seconds(raw: &str) -> Option<u64> {
    let (date, time) = raw.trim().strip_suffix('Z')?.split_once('T')?;
    let mut date = date.splitn(3, '-').map(str::parse::<i64>);
    let (year, month, day) = (date.next()?.ok()?, date.next()?.ok()?, date.next()?.ok()?);
    let whole = time.split('.').next()?;
    let mut time = whole.splitn(3, ':').map(str::parse::<i64>);
    let (hour, minute, second) = (time.next()?.ok()?, time.next()?.ok()?, time.next()?.ok()?);
    if !(1..=12).contains(&month)
        || !(1..=31).contains(&day)
        || hour > 23
        || minute > 59
        || second > 60
    {
        return None;
    }
    let seconds = days_from_civil(year, month, day) * 86_400 + hour * 3_600 + minute * 60 + second;
    u64::try_from(seconds).ok().filter(|&seconds| seconds > 0)
}

pub fn parse_own_login(raw: &str) -> Option<String> {
    let status = serde_json::from_str::<Status>(raw).ok()?;
    let login = status
        .users
        .get(&status.own.user.to_string())?
        .login
        .clone();
    (!login.is_empty()).then_some(login)
}

pub fn parse_identity(raw: &str) -> Option<Identity> {
    let whois = serde_json::from_str::<Whois>(raw).ok()?;
    let host = label(&whois.node.name, "");
    (!whois.profile.login.is_empty() && !host.is_empty()).then_some(Identity {
        login: whois.profile.login,
        host,
    })
}

const SECURE: u16 = 443;

#[derive(Deserialize)]
struct Listener {
    #[serde(rename = "HTTPS", default)]
    https: bool,
}

#[derive(Deserialize)]
struct Handler {
    #[serde(rename = "Proxy", default)]
    proxy: String,
}

#[derive(Deserialize)]
struct WebHost {
    #[serde(rename = "Handlers", default)]
    handlers: HashMap<String, Handler>,
}

#[derive(Deserialize)]
struct Served {
    #[serde(rename = "TCP", default)]
    tcp: HashMap<String, Listener>,
    #[serde(rename = "Web", default)]
    web: HashMap<String, WebHost>,
}

fn proxied_port(proxy: &str) -> Option<u16> {
    let rest = proxy.split_once("://").map_or(proxy, |(_, rest)| rest);
    let authority = rest.split('/').next()?;
    authority.rsplit_once(':')?.1.parse().ok()
}

fn secured(served: &Served, front: &str) -> bool {
    front.parse() == Ok(SECURE) && served.tcp.get(front).is_some_and(|tcp| tcp.https)
}

pub fn parse_fronted(raw: &str, port: u16) -> Option<String> {
    let served = serde_json::from_str::<Served>(raw).ok()?;
    served
        .web
        .iter()
        .filter(|(_, host)| {
            host.handlers
                .values()
                .any(|handler| proxied_port(&handler.proxy) == Some(port))
        })
        .filter_map(|(at, _)| at.rsplit_once(':'))
        .filter(|(name, front)| !name.is_empty() && secured(&served, front))
        .map(|(name, _)| name.to_owned())
        .min()
}

fn run(args: &[&str]) -> Result<String> {
    let out = Command::new("tailscale")
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .context("cannot run tailscale")?;
    if !out.status.success() {
        bail!(
            "tailscale {} failed: {}",
            args.join(" "),
            String::from_utf8_lossy(&out.stderr).trim()
        );
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

pub fn peers(allowed: &[String]) -> Vec<Peer> {
    match run(&["status", "--json"]) {
        Ok(raw) => parse_peers(&raw, allowed),
        Err(_) => Vec::new(),
    }
}

pub fn sightings() -> Vec<Sighting> {
    match run(&["status", "--json"]) {
        Ok(raw) => parse_sightings(&raw),
        Err(_) => Vec::new(),
    }
}

pub fn own_login() -> Option<String> {
    parse_own_login(&run(&["status", "--json"]).ok()?)
}

pub fn identity_of(address: Ipv4Addr) -> Option<Identity> {
    parse_identity(&run(&["whois", "--json", &address.to_string()]).ok()?)
}

pub fn fronted(port: u16) -> Option<String> {
    parse_fronted(&run(&["serve", "status", "--json"]).ok()?, port)
}
