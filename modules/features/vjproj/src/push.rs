use crate::paths::Dirs;
use crate::tailnet;
use anyhow::{Context, Result, bail};
use base64::Engine;
use p256::SecretKey;
use p256::ecdsa::{Signature, SigningKey, signature::Signer};
use serde_json::json;
use std::fs;
use std::process::{Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

const BYTES: usize = 32;

const TRIES: usize = 8;

const LIFETIME: u64 = 43200;

const KEEP: usize = 20;

const TIMEOUT: &str = "5";

const TTL: &str = "86400";

const HEADER: &str = r#"{"typ":"JWT","alg":"ES256"}"#;

fn urlsafe(raw: &[u8]) -> String {
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(raw)
}

pub fn seconds() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|since| since.as_secs())
        .unwrap_or(0)
}

pub struct Key(SigningKey);

impl Key {
    pub fn kept(dirs: &Dirs) -> Result<Self> {
        let path = dirs.push_key();
        if let Ok(raw) = fs::read_to_string(&path)
            && let Some(secret) = unhex(raw.trim()).and_then(|raw| SecretKey::from_slice(&raw).ok())
        {
            return Ok(Self(SigningKey::from(secret)));
        }
        let fresh = minted()?;
        vjcommon::atomic::write_private(&path, hex(&fresh.to_bytes()).as_bytes())?;
        Ok(Self(SigningKey::from(fresh)))
    }

    pub fn public_key(&self) -> String {
        urlsafe(self.0.verifying_key().to_sec1_point(false).as_bytes())
    }

    pub fn signed(&self, audience: &str, subject: &str, now: u64) -> String {
        let claims = json!({
            "aud": audience,
            "exp": now + LIFETIME,
            "sub": subject,
        });
        let opening = format!(
            "{}.{}",
            urlsafe(HEADER.as_bytes()),
            urlsafe(claims.to_string().as_bytes())
        );
        let mark: Signature = self.0.sign(opening.as_bytes());
        format!("{opening}.{}", urlsafe(&mark.to_bytes()))
    }
}

fn minted() -> Result<SecretKey> {
    for _ in 0..TRIES {
        if let Ok(secret) = SecretKey::from_slice(&entropy()?) {
            return Ok(secret);
        }
    }
    bail!("cannot draw a signing key out of /dev/urandom")
}

fn entropy() -> Result<[u8; BYTES]> {
    let mut raw = [0u8; BYTES];
    std::io::Read::read_exact(
        &mut fs::File::open("/dev/urandom").context("cannot open /dev/urandom")?,
        &mut raw,
    )
    .context("cannot read /dev/urandom")?;
    Ok(raw)
}

fn hex(raw: &[u8]) -> String {
    raw.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn unhex(raw: &str) -> Option<Vec<u8>> {
    let digits = raw.as_bytes();
    if digits.len() != BYTES * 2 {
        return None;
    }
    digits
        .chunks(2)
        .map(|pair| u8::from_str_radix(std::str::from_utf8(pair).ok()?, 16).ok())
        .collect()
}

pub fn audience_of(endpoint: &str) -> Option<String> {
    let (scheme, rest) = endpoint.split_once("://")?;
    if scheme.is_empty() || !scheme.bytes().all(|c| c.is_ascii_alphabetic()) {
        return None;
    }
    let host = rest.split(['/', '?', '#']).next()?;
    (!host.is_empty()).then(|| format!("{scheme}://{host}"))
}

pub fn secure(endpoint: &str) -> bool {
    audience_of(endpoint).is_some_and(|origin| origin.starts_with("https://"))
}

pub fn added(known: Vec<String>, endpoint: &str) -> Vec<String> {
    if known.iter().any(|held| held == endpoint) {
        return known;
    }
    let mut kept = known;
    kept.push(endpoint.to_owned());
    let over = kept.len().saturating_sub(KEEP);
    kept.drain(..over);
    kept
}

pub fn dropped(known: Vec<String>, endpoint: &str) -> Vec<String> {
    known.into_iter().filter(|held| held != endpoint).collect()
}

pub fn load(dirs: &Dirs) -> Vec<String> {
    fs::read_to_string(dirs.subscriptions())
        .ok()
        .and_then(|raw| serde_json::from_str(&raw).ok())
        .unwrap_or_default()
}

fn save(dirs: &Dirs, endpoints: &[String]) -> Result<()> {
    let body = serde_json::to_string(endpoints).context("cannot serialize subscriptions")?;
    vjcommon::atomic::write(&dirs.subscriptions(), body.as_bytes())
}

pub fn subscribe(dirs: &Dirs, endpoint: &str) -> Result<()> {
    save(dirs, &added(load(dirs), endpoint))
}

pub fn forget(dirs: &Dirs, endpoint: &str) -> Result<()> {
    save(dirs, &dropped(load(dirs), endpoint))
}

pub fn subject(port: u16) -> Option<String> {
    tailnet::fronted(port).map(|host| format!("https://{host}"))
}

pub fn gone(code: Option<u16>) -> bool {
    matches!(code, Some(404) | Some(410))
}

fn posted(key: &Key, endpoint: &str, subject: &str, now: u64) -> Option<u16> {
    let audience = audience_of(endpoint)?;
    let vapid = format!(
        "vapid t={}, k={}",
        key.signed(&audience, subject, now),
        key.public_key()
    );
    let out = Command::new("curl")
        .args(["--silent", "--show-error", "--max-time", TIMEOUT])
        .args(["--output", "/dev/null", "--write-out", "%{http_code}"])
        .args(["--request", "POST"])
        .args(["--header", &format!("Authorization: {vapid}")])
        .args(["--header", &format!("TTL: {TTL}")])
        .args(["--header", "Urgency: high"])
        .args(["--header", "Content-Length: 0"])
        .arg(endpoint)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .ok()?;
    String::from_utf8_lossy(&out.stdout).trim().parse().ok()
}

pub fn notify(dirs: &Dirs, subject: &str) {
    let known = load(dirs);
    if known.is_empty() {
        return;
    }
    let Ok(key) = Key::kept(dirs) else {
        return;
    };
    let now = seconds();
    let dead: Vec<String> = known
        .into_iter()
        .filter(|endpoint| gone(posted(&key, endpoint, subject, now)))
        .collect();
    for endpoint in &dead {
        let _ = forget(dirs, endpoint);
    }
}
