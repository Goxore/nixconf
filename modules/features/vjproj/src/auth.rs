use crate::held;
use crate::paths::Dirs;
use crate::tailnet;
use anyhow::{Context, Result};
use std::collections::HashMap;
use std::fs;
use std::net::Ipv4Addr;
use std::sync::Mutex;
use std::time::{Duration, Instant};

const BYTES: usize = 32;

const REMEMBER: Duration = Duration::from_secs(60);

pub fn token(dirs: &Dirs) -> Result<String> {
    let path = dirs.token();
    if let Ok(raw) = fs::read_to_string(&path) {
        let existing = raw.trim();
        if !existing.is_empty() {
            return Ok(existing.to_owned());
        }
    }
    let fresh = generate()?;
    vjcommon::atomic::write_private(&path, fresh.as_bytes())?;
    Ok(fresh)
}

fn generate() -> Result<String> {
    let mut raw = [0u8; BYTES];
    std::io::Read::read_exact(
        &mut fs::File::open("/dev/urandom").context("cannot open /dev/urandom")?,
        &mut raw,
    )
    .context("cannot read /dev/urandom")?;
    Ok(raw.iter().map(|byte| format!("{byte:02x}")).collect())
}

pub fn matches(expected: &str, given: Option<&str>) -> bool {
    let Some(given) = given else {
        return false;
    };
    if expected.len() != given.len() {
        return false;
    }
    expected
        .bytes()
        .zip(given.bytes())
        .fold(0u8, |differs, (a, b)| differs | (a ^ b))
        == 0
}

pub fn presented<'a>(header: Option<&'a str>, query: Option<&'a str>) -> Option<&'a str> {
    match header.and_then(|value| value.strip_prefix("Bearer ")) {
        Some(bearer) => Some(bearer.trim()),
        None => query,
    }
}

pub struct Trust {
    own: Option<String>,
    allowed: Vec<String>,
    seen: Mutex<HashMap<Ipv4Addr, (bool, Instant)>>,
}

impl Trust {
    pub fn of_tailnet(allowed: Vec<String>) -> Self {
        Self {
            own: tailnet::own_login(),
            allowed,
            seen: Mutex::new(HashMap::new()),
        }
    }

    pub fn nobody() -> Self {
        Self {
            own: None,
            allowed: Vec::new(),
            seen: Mutex::new(HashMap::new()),
        }
    }

    fn remembered(&self, address: Ipv4Addr) -> Option<bool> {
        let seen = held(&self.seen);
        let &(verdict, at) = seen.get(&address)?;
        (at.elapsed() < REMEMBER).then_some(verdict)
    }

    pub fn allows(&self, address: Ipv4Addr) -> bool {
        let Some(own) = &self.own else {
            return false;
        };
        if !tailnet::is_tailnet(address) || self.allowed.is_empty() {
            return false;
        }
        if let Some(verdict) = self.remembered(address) {
            return verdict;
        }
        let verdict = tailnet::identity_of(address)
            .is_some_and(|who| &who.login == own && self.allowed.contains(&who.host));
        held(&self.seen).insert(address, (verdict, Instant::now()));
        verdict
    }
}
