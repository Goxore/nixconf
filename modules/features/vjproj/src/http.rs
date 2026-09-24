use crate::attach::Attached;
use crate::devices::{self, Device, Kind};
use crate::held;
use crate::paths::Dirs;
use crate::peers::PeerView;
use crate::shells::Untouched;
use crate::{attach, auth, peers, push, shells, tmux};
use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::{Value, json};
use std::io::Read;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use tiny_http::{Header, ReadWrite, Request, Response, Server};
use tungstenite::handshake::derive_accept_key;

const BODY_CAP: u64 = 64 * 1024;

const WORKERS: usize = 4;

const SWEEP: Duration = Duration::from_secs(2);

pub const FORWARDED: &str = "x-vjproj-forwarded";

pub struct Serving {
    pub dirs: Dirs,
    pub latest: Arc<Mutex<Option<Value>>>,
    pub token: String,
    pub www: PathBuf,
    pub editing: Option<PathBuf>,
    pub port: u16,
    pub peers: Arc<Mutex<Vec<PeerView>>>,
    pub devices: Arc<Mutex<Vec<Device>>>,
    pub trust: auth::Trust,
    pub shells: Untouched,
    pub attaching: Attached,
}

impl Serving {
    fn stamp(&self) -> String {
        built_stamp(&self.www)
    }

    fn asset_path(&self, name: &str) -> PathBuf {
        match &self.editing {
            Some(dir) if dir.join(name).is_file() => dir.join(name),
            _ => self.www.join(name),
        }
    }
}

#[derive(Deserialize)]
struct Started {
    kind: String,
    #[serde(default)]
    project: Option<u8>,
}

fn opened(address: Ipv4Addr, port: u16) -> Result<Arc<Server>> {
    let at = SocketAddr::from((address, port));
    let server = Server::http(at)
        .map_err(|e| anyhow::anyhow!("{e}"))
        .with_context(|| format!("cannot listen on {at}"))?;
    Ok(Arc::new(server))
}

pub fn doors(address: Ipv4Addr) -> Vec<Ipv4Addr> {
    if address == Ipv4Addr::LOCALHOST {
        vec![address]
    } else {
        vec![address, Ipv4Addr::LOCALHOST]
    }
}

pub fn bind(address: Ipv4Addr, port: u16) -> Result<Vec<Arc<Server>>> {
    doors(address)
        .into_iter()
        .map(|door| opened(door, port))
        .collect()
}

pub fn serve(servers: Vec<Arc<Server>>, serving: Serving) -> Result<()> {
    let serving = Arc::new(serving);

    let reaping = Arc::clone(&serving);
    thread::spawn(move || {
        loop {
            thread::sleep(SWEEP);
            sweep(&reaping);
        }
    });

    let mut crew = Vec::new();
    for server in &servers {
        for _ in 0..WORKERS {
            let server = Arc::clone(server);
            let serving = Arc::clone(&serving);
            crew.push(thread::spawn(move || {
                while let Ok(request) = server.recv() {
                    let _ = handle(&serving, request);
                }
            }));
        }
    }
    for worker in crew {
        let _ = worker.join();
    }
    Ok(())
}

fn handle(serving: &Arc<Serving>, mut request: Request) -> std::io::Result<()> {
    let (path, query) = split_url(request.url());
    let method = request.method().as_str().to_owned();
    let wanted = size_in(query);

    if !public(&method, &path) {
        if !same_origin(
            header_of(&request, "origin").as_deref(),
            header_of(&request, "host").as_deref(),
        ) {
            return request.respond(json_response(403, &json!({"error": "cross origin"})));
        }
        let header = header_of(&request, "authorization");
        let query = if method == "GET" { query } else { None };
        let given = auth::presented(header.as_deref(), token_in(query));
        if !auth::matches(&serving.token, given) && !vouched(serving, &request, &method, &path) {
            return request.respond(json_response(401, &json!({"error": "unauthorized"})));
        }
    }

    if method == "GET"
        && asset_named(&path).is_some_and(|(name, _)| keeps(name))
        && header_of(&request, "if-none-match").as_deref() == Some(serving.stamp().as_str())
    {
        return request.respond(Response::empty(304).with_header(named("ETag", &serving.stamp())));
    }

    if method == "GET"
        && let Some(asked) = attaching(&path)
    {
        return lift(serving, request, asked, wanted);
    }

    let body = read_body(&mut request);
    let response = route(serving, &method, &path, &body);
    request.respond(response)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Way {
    Out,
    In,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Asking {
    pub peer: Option<String>,
    pub pane: String,
    pub way: Way,
}

pub fn attaching(path: &str) -> Option<Asking> {
    let segments: Vec<&str> = path.split('/').filter(|part| !part.is_empty()).collect();
    let (peer, rest) = match segments.as_slice() {
        ["at", host, rest @ ..] => (Some((*host).to_owned()), rest),
        rest => (None, rest),
    };
    let (pane, way) = match rest {
        ["pane", pane, "out"] => (pane, Way::Out),
        ["pane", pane, "in"] => (pane, Way::In),
        _ => return None,
    };
    Some(Asking {
        peer,
        pane: (*pane).to_owned(),
        way,
    })
}

fn numbered(query: Option<&str>, name: &str) -> Option<u16> {
    query?
        .split('&')
        .filter_map(|pair| pair.split_once('='))
        .find(|(key, _)| *key == name)
        .and_then(|(_, value)| value.parse().ok())
}

pub fn size_in(query: Option<&str>) -> attach::Size {
    attach::Size::fitted(
        numbered(query, "cols").unwrap_or(80),
        numbered(query, "rows").unwrap_or(24),
    )
}

fn accepting(request: &Request) -> Option<String> {
    let upgrade = header_of(request, "upgrade")?;
    if !upgrade.trim().eq_ignore_ascii_case("websocket") {
        return None;
    }
    let key = header_of(request, "sec-websocket-key")?;
    Some(derive_accept_key(key.trim().as_bytes()))
}

fn lift(
    serving: &Arc<Serving>,
    request: Request,
    asked: Asking,
    wanted: attach::Size,
) -> std::io::Result<()> {
    if tmux::target(&asked.pane).is_err() {
        return request.respond(json_response(400, &json!({"error": "no such pane"})));
    }
    let Some(accept) = accepting(&request) else {
        return request.respond(json_response(400, &json!({"error": "not a websocket"})));
    };

    let handshake = Response::empty(101).with_header(named("Sec-WebSocket-Accept", &accept));
    let stream = request.upgrade("websocket", handshake);
    let serving = Arc::clone(serving);
    thread::spawn(move || pump(&serving, asked, wanted, stream));
    Ok(())
}

fn pump(serving: &Serving, asked: Asking, wanted: attach::Size, stream: Box<dyn ReadWrite + Send>) {
    if let Some(host) = &asked.peer {
        let _ = relay(serving, host, &asked, wanted, stream);
        return;
    }
    let Ok(pane) = tmux::target(&asked.pane) else {
        return;
    };
    match asked.way {
        Way::Out => {
            let _ = attach::downstream(&serving.attaching, &pane, wanted, stream);
        }
        Way::In => {
            let number = asked.pane.clone();
            let _ = attach::upstream(&serving.attaching, &pane, stream, || {
                serving.shells.touched(&number)
            });
        }
    }
}

fn relay(
    serving: &Serving,
    host: &str,
    asked: &Asking,
    wanted: attach::Size,
    stream: Box<dyn ReadWrite + Send>,
) -> Result<()> {
    let known = held(&serving.peers).clone();
    let address =
        peers::located(&known, host).with_context(|| format!("no machine named {host}"))?;
    let tail = match asked.way {
        Way::Out => "out",
        Way::In => "in",
    };
    let path = format!(
        "/pane/{}/{}?cols={}&rows={}",
        asked.pane, tail, wanted.cols, wanted.rows
    );
    let far = attach::dialed(address, serving.port, &path)?;
    let near = attach::wrapped(stream);
    match asked.way {
        Way::Out => attach::ferry(far, near),
        Way::In => attach::ferry(near, far),
    }
    Ok(())
}

fn caller(request: &Request) -> Option<Ipv4Addr> {
    match request.remote_addr().map(SocketAddr::ip) {
        Some(IpAddr::V4(address)) => Some(address),
        _ => None,
    }
}

pub fn reads_only(method: &str, path: &str) -> bool {
    method == "GET" && path.trim_end_matches('/') == "/state"
}

pub fn same_origin(origin: Option<&str>, host: Option<&str>) -> bool {
    let Some(origin) = origin else {
        return true;
    };
    let claimed = origin
        .strip_prefix("http://")
        .or_else(|| origin.strip_prefix("https://"));
    match (claimed, host) {
        (Some(claimed), Some(host)) => !host.is_empty() && claimed == host,
        _ => false,
    }
}

fn vouched(serving: &Serving, request: &Request, method: &str, path: &str) -> bool {
    let Some(address) = caller(request) else {
        return false;
    };
    if !serving.trust.allows(address) {
        return false;
    }
    if reads_only(method, path) {
        return true;
    }
    header_of(request, FORWARDED).is_some() && answering(serving, address)
}

fn answering(serving: &Serving, address: Ipv4Addr) -> bool {
    held(&serving.peers)
        .iter()
        .any(|peer| peer.address == address.to_string())
}

pub const ASSETS: [(&str, &str); 13] = [
    ("index.html", "text/html; charset=utf-8"),
    ("app.js", "text/javascript; charset=utf-8"),
    ("app.css", "text/css; charset=utf-8"),
    ("theme.css", "text/css; charset=utf-8"),
    ("sw.js", "text/javascript; charset=utf-8"),
    ("manifest.webmanifest", "application/manifest+json"),
    ("icons.woff2", "font/woff2"),
    ("icons.json", "application/json"),
    ("regular.woff2", "font/woff2"),
    ("medium.woff2", "font/woff2"),
    ("icon-192.png", "image/png"),
    ("icon-512.png", "image/png"),
    ("icon-mask.png", "image/png"),
];

pub fn built_stamp(www: &std::path::Path) -> String {
    let build = www
        .file_name()
        .map(|name| name.to_string_lossy())
        .unwrap_or_default();
    format!("\"{build}\"")
}

pub fn keeps(name: &str) -> bool {
    name.ends_with(".woff2") || name.ends_with(".png")
}

pub fn asset_named(path: &str) -> Option<(&'static str, &'static str)> {
    let name = path.trim_start_matches('/');
    if name.is_empty() {
        return Some(ASSETS[0]);
    }
    ASSETS.into_iter().find(|(known, _)| *known == name)
}

pub fn public(method: &str, path: &str) -> bool {
    method == "GET" && asset_named(path).is_some()
}

fn route(
    serving: &Serving,
    method: &str,
    path: &str,
    body: &str,
) -> Response<std::io::Cursor<Vec<u8>>> {
    let segments: Vec<&str> = path.split('/').filter(|part| !part.is_empty()).collect();

    if method == "GET"
        && let Some((name, kind)) = asset_named(path)
    {
        return asset(serving, name, kind);
    }

    if let ["at", host, rest @ ..] = segments.as_slice() {
        return outcome(elsewhere(serving, method, host, rest, body));
    }

    match (method, segments.as_slice()) {
        ("GET", ["state"]) => ok(state(serving)),
        ("POST", ["pane", number, "close"]) => outcome(closed(serving, number)),
        ("POST", ["agent"]) => outcome(started(serving, body)),
        ("POST", ["shell"]) => outcome(shelled(serving, body)),
        ("POST", ["shell", number, "release"]) => outcome(released(serving, number)),
        ("POST", ["shelf", id]) => outcome(adopted(serving, id)),
        ("POST", ["project"]) => outcome(created(serving, body)),
        ("POST", ["project", number]) => outcome(switched(serving, number)),
        ("GET", ["push", "key"]) => outcome(push_key(serving)),
        ("POST", ["push", "subscribe"]) => outcome(subscribed(serving, body)),
        ("POST", ["push", "forget"]) => outcome(unsubscribed(serving, body)),
        ("POST", ["battery"]) => outcome(charged(serving, body)),
        _ => json_response(404, &json!({"error": "no such route"})),
    }
}

fn state(serving: &Serving) -> Value {
    held(&serving.latest).clone().unwrap_or_else(|| json!({}))
}

fn elsewhere(
    serving: &Serving,
    method: &str,
    host: &str,
    rest: &[&str],
    body: &str,
) -> Result<Value> {
    if rest.first() == Some(&"at") {
        anyhow::bail!("machines cannot be chained");
    }
    let known = held(&serving.peers).clone();
    let address =
        peers::located(&known, host).with_context(|| format!("no machine named {host}"))?;
    let path = format!("/{}", rest.join("/"));
    peers::forward(address, serving.port, method, &path, body)
        .with_context(|| format!("{host} did not answer {method} {path}"))
}

#[derive(Deserialize)]
struct Charged {
    device: String,
    level: u8,
    charging: bool,
}

pub fn is_phone(known: &[Device], id: &str) -> bool {
    known
        .iter()
        .any(|device| device.id == id && device.kind == Kind::Phone)
}

fn charged(serving: &Serving, body: &str) -> Result<Value> {
    let charged: Charged = serde_json::from_str(body).context("cannot parse body")?;
    if !is_phone(&held(&serving.devices), &charged.device) {
        anyhow::bail!("{} is not a phone on this tailnet", charged.device);
    }
    let battery = devices::report(
        &serving.dirs,
        &charged.device,
        charged.level,
        charged.charging,
        devices::now(),
    )?;
    Ok(serde_json::to_value(battery)?)
}

fn closed(serving: &Serving, number: &str) -> Result<Value> {
    let pane = tmux::target(number)?;
    serving.shells.touched(number);
    tmux::close(&pane)?;
    Ok(json!({"closed": true}))
}

fn started(serving: &Serving, body: &str) -> Result<Value> {
    let started: Started = serde_json::from_str(body).context("cannot parse body")?;
    let project = started.project.context("an agent needs a project")?;
    let dir = crate::project_dir(&serving.dirs, project)?;
    crate::launch::agent(&started.kind, &dir, project)?;
    Ok(json!({"project": project}))
}

#[derive(Deserialize)]
struct Opened {
    project: u8,
}

fn shelled(serving: &Serving, body: &str) -> Result<Value> {
    let opened: Opened = serde_json::from_str(body).context("cannot parse body")?;
    let dir = crate::project_dir(&serving.dirs, opened.project)?;
    let (pane, fresh) = tmux::shell(&dir, opened.project)?;
    if fresh {
        serving.shells.opened(opened.project, &pane, Instant::now());
    }
    Ok(json!({"pane": pane, "project": opened.project, "fresh": fresh}))
}

fn released(serving: &Serving, number: &str) -> Result<Value> {
    let project: u8 = number.parse().context("project must be a number")?;
    match serving.shells.released(project) {
        Some(opened) => {
            tmux::end_session(opened.project)?;
            Ok(json!({"closed": true, "project": project}))
        }
        None => Ok(json!({"closed": false, "project": project})),
    }
}

fn sweep(serving: &Serving) {
    let now = Instant::now();
    for opened in serving.shells.stale(now, shells::STALE) {
        let _ = tmux::end_session(opened.project);
    }
    for (pane, epoch) in serving.attaching.gone_quiet(now, attach::FORGOTTEN) {
        serving.attaching.closed(&pane, epoch);
    }
}

#[derive(Deserialize)]
struct Made {
    dir: String,
}

fn created(serving: &Serving, body: &str) -> Result<Value> {
    let made: Made = serde_json::from_str(body).context("cannot parse body")?;
    let project = crate::create_project(&serving.dirs, &PathBuf::from(&made.dir))?;
    Ok(json!({"project": project}))
}

fn adopted(serving: &Serving, id: &str) -> Result<Value> {
    let id: u32 = id.parse().context("shelf id must be a number")?;
    let project = crate::adopt_shelf(&serving.dirs, id)?;
    Ok(json!({"project": project}))
}

fn switched(serving: &Serving, number: &str) -> Result<Value> {
    let project: u8 = number.parse().context("project must be a number")?;
    crate::switch(&serving.dirs, project)?;
    Ok(json!({"switched": true}))
}

fn push_key(serving: &Serving) -> Result<Value> {
    let key = push::Key::kept(&serving.dirs)?;
    Ok(json!({"key": key.public_key()}))
}

#[derive(Deserialize)]
struct Wanting {
    endpoint: String,
}

fn wanted(body: &str) -> Result<String> {
    let asked: Wanting = serde_json::from_str(body).context("cannot parse body")?;
    if !push::secure(&asked.endpoint) {
        anyhow::bail!("a push endpoint must be an https url");
    }
    Ok(asked.endpoint)
}

fn subscribed(serving: &Serving, body: &str) -> Result<Value> {
    push::subscribe(&serving.dirs, &wanted(body)?)?;
    Ok(json!({}))
}

fn unsubscribed(serving: &Serving, body: &str) -> Result<Value> {
    push::forget(&serving.dirs, &wanted(body)?)?;
    Ok(json!({}))
}

fn asset(serving: &Serving, name: &str, kind: &str) -> Response<std::io::Cursor<Vec<u8>>> {
    match std::fs::read(serving.asset_path(name)) {
        Ok(body) => Response::from_data(body)
            .with_header(content_type(kind))
            .with_header(cache_rule(name))
            .with_header(named("ETag", &serving.stamp())),
        Err(_) => json_response(500, &json!({"error": "the page is missing"})),
    }
}

fn cache_rule(name: &str) -> Header {
    let value = if keeps(name) { "no-cache" } else { "no-store" };
    Header::from_bytes(&b"Cache-Control"[..], value.as_bytes())
        .unwrap_or_else(|_| unreachable!("the cache header is a fixed ascii string"))
}

fn outcome(result: Result<Value>) -> Response<std::io::Cursor<Vec<u8>>> {
    match result {
        Ok(value) => ok(value),
        Err(e) => json_response(400, &json!({"error": format!("{e:#}")})),
    }
}

fn ok(value: Value) -> Response<std::io::Cursor<Vec<u8>>> {
    json_response(200, &value)
}

fn json_response(status: u16, value: &Value) -> Response<std::io::Cursor<Vec<u8>>> {
    let body = serde_json::to_vec(value).unwrap_or_default();
    Response::from_data(body)
        .with_status_code(status)
        .with_header(content_type("application/json"))
}

fn content_type(value: &str) -> Header {
    Header::from_bytes(&b"Content-Type"[..], value.as_bytes())
        .unwrap_or_else(|_| unreachable!("the content type is a fixed ascii string"))
}

fn named(field: &str, value: &str) -> Header {
    Header::from_bytes(field.as_bytes(), value.as_bytes())
        .unwrap_or_else(|_| unreachable!("the header is a fixed ascii string"))
}

fn read_body(request: &mut Request) -> String {
    let mut body = String::new();
    let _ = request.as_reader().take(BODY_CAP).read_to_string(&mut body);
    body
}

fn header_of(request: &Request, name: &'static str) -> Option<String> {
    request
        .headers()
        .iter()
        .find(|header| header.field.equiv(name))
        .map(|header| header.value.as_str().to_owned())
}

pub fn split_url(url: &str) -> (String, Option<&str>) {
    match url.split_once('?') {
        Some((path, query)) => (path.to_owned(), Some(query)),
        None => (url.to_owned(), None),
    }
}

pub fn token_in(query: Option<&str>) -> Option<&str> {
    query?
        .split('&')
        .find_map(|pair| pair.strip_prefix("token="))
}
