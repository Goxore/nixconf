use std::io::{Read, Write};
use std::net::{Ipv4Addr, TcpStream};
use std::sync::OnceLock;
use std::thread;
use vjproj::http::{self, Serving};

const TOKEN: &str = "0123456789abcdef";

struct Reply {
    status: u16,
    body: String,
}

fn port() -> u16 {
    static SERVING: OnceLock<u16> = OnceLock::new();
    *SERVING.get_or_init(|| {
        let www = tempfile::tempdir().unwrap().keep();
        std::fs::write(www.join("index.html"), b"<!doctype html><title>t</title>").unwrap();
        std::fs::write(www.join("theme.css"), b":root { --bg: #181818; }").unwrap();

        let servers = http::bind(Ipv4Addr::LOCALHOST, 0).unwrap();
        let port = servers[0].server_addr().to_ip().unwrap().port();
        let serving = Serving {
            dirs: vjproj::paths::Dirs {
                runtime: www.clone(),
                data: www.clone(),
            },
            latest: std::sync::Arc::new(std::sync::Mutex::new(None)),
            token: TOKEN.into(),
            www,
            editing: None,
            port,
            peers: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
            devices: std::sync::Arc::new(std::sync::Mutex::new(vec![vjproj::devices::Device {
                id: "pixel-8a".into(),
                name: "Pixel 8a".into(),
                kind: vjproj::devices::Kind::Phone,
                ..Default::default()
            }])),
            trust: vjproj::auth::Trust::nobody(),
            shells: vjproj::shells::Untouched::new(),
            attaching: vjproj::attach::Attached::new(),
        };
        thread::spawn(move || http::serve(servers, serving));
        port
    })
}

fn ask(method: &str, path: &str, token: Option<&str>) -> Reply {
    ask_with(method, path, token, "")
}

fn ask_with(method: &str, path: &str, token: Option<&str>, extra: &str) -> Reply {
    let mut stream = TcpStream::connect((Ipv4Addr::LOCALHOST, port())).unwrap();
    let auth = match token {
        Some(token) => format!("Authorization: Bearer {token}\r\n"),
        None => String::new(),
    };
    write!(
        stream,
        "{method} {path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n{auth}{extra}Content-Length: 0\r\n\r\n"
    )
    .unwrap();

    let mut raw = String::new();
    stream.read_to_string(&mut raw).unwrap();
    let (head, body) = raw.split_once("\r\n\r\n").unwrap_or((raw.as_str(), ""));
    Reply {
        status: head
            .split_whitespace()
            .nth(1)
            .and_then(|code| code.parse().ok())
            .unwrap_or(0),
        body: body.to_owned(),
    }
}

fn post(path: &str, token: Option<&str>, body: &str) -> Reply {
    let mut stream = TcpStream::connect((Ipv4Addr::LOCALHOST, port())).unwrap();
    let auth = match token {
        Some(token) => format!("Authorization: Bearer {token}\r\n"),
        None => String::new(),
    };
    write!(
        stream,
        "POST {path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n{auth}Content-Type: application/json\r\nContent-Length: {}\r\n\r\n{body}",
        body.len()
    )
    .unwrap();
    let mut raw = String::new();
    stream.read_to_string(&mut raw).unwrap();
    let (head, body) = raw.split_once("\r\n\r\n").unwrap_or((raw.as_str(), ""));
    Reply {
        status: head
            .split_whitespace()
            .nth(1)
            .and_then(|code| code.parse().ok())
            .unwrap_or(0),
        body: body.to_owned(),
    }
}

#[test]
fn a_phone_reports_its_battery_with_the_token() {
    let body = r#"{"device":"pixel-8a","level":76,"charging":true}"#;
    assert_eq!(post("/battery", None, body).status, 401);

    let reply = post("/battery", Some(TOKEN), body);
    assert_eq!(reply.status, 200, "{}", reply.body);
    let battery: serde_json::Value = serde_json::from_str(&reply.body).unwrap();
    assert_eq!(battery["level"], 76);
    assert_eq!(battery["charging"], true);
}

#[test]
fn only_a_known_phone_with_a_real_level_can_report() {
    let stranger = r#"{"device":"main","level":50,"charging":false}"#;
    assert_eq!(post("/battery", Some(TOKEN), stranger).status, 400);

    let impossible = r#"{"device":"pixel-8a","level":150,"charging":false}"#;
    assert_eq!(post("/battery", Some(TOKEN), impossible).status, 400);

    let garbled = r#"{"device":"pixel-8a","level":"high"}"#;
    assert_eq!(post("/battery", Some(TOKEN), garbled).status, 400);
}

#[test]
fn a_request_without_the_token_is_turned_away() {
    assert_eq!(ask("GET", "/state", None).status, 401);
    assert_eq!(ask("GET", "/state", Some("wrong")).status, 401);
    assert_eq!(ask("POST", "/agent", None).status, 401);
    assert_eq!(ask("GET", "/pane/0", None).status, 401);
}

#[test]
fn the_page_loads_before_the_browser_has_any_token() {
    let reply = ask("GET", "/", None);
    assert_eq!(reply.status, 200);
    assert!(reply.body.contains("<!doctype html>"));
}

#[test]
fn only_the_static_assets_are_ever_public() {
    assert!(http::public("GET", "/"));
    assert!(http::public("GET", ""));
    assert!(http::public("GET", "/theme.css"));
    assert!(http::public("GET", "/icons.woff2"));
    assert!(http::public("GET", "/icons.json"));
    assert!(!http::public("GET", "/state"));
    assert!(!http::public("GET", "/pane/0"));
    assert!(!http::public("POST", "/"));
    assert!(!http::public("GET", "/theme.css/../state"));
    assert!(!http::public("GET", "/../../etc/passwd"));
    assert!(!http::public("GET", "/icons.woff2/../../state"));
}

#[test]
fn the_stylesheet_loads_without_a_token_because_a_link_tag_sends_none() {
    let reply = ask("GET", "/theme.css", None);
    assert_eq!(reply.status, 200);
    assert!(reply.body.contains("--bg"));
}

#[test]
fn the_token_opens_the_state_feed() {
    let reply = ask("GET", "/state", Some(TOKEN));
    assert_eq!(reply.status, 200);
    assert!(reply.body.starts_with('{'), "got {}", reply.body);
}

#[test]
fn the_token_may_ride_in_the_query_string() {
    assert_eq!(
        ask("GET", &format!("/state?token={TOKEN}"), None).status,
        200
    );
}

#[test]
fn a_leaked_link_can_still_never_be_used_to_act() {
    let armed = format!("/pane/1/close?token={TOKEN}");

    assert_eq!(
        ask("POST", &armed, None).status,
        401,
        "a token in the query must not authorise a write"
    );
}

#[test]
fn another_website_cannot_post_to_us_even_holding_the_token() {
    let reply = ask_with(
        "POST",
        "/agent",
        Some(TOKEN),
        "Origin: http://evil.example\r\n",
    );

    assert_eq!(reply.status, 403);
}

#[test]
fn our_own_page_posts_with_its_origin_and_is_let_through() {
    let reply = ask_with(
        "POST",
        "/nowhere",
        Some(TOKEN),
        "Origin: http://localhost\r\n",
    );

    assert_eq!(
        reply.status, 404,
        "rejected on the route, not on the origin"
    );
}

#[test]
fn a_browser_on_a_trusted_machine_cannot_forge_a_forwarded_call() {
    let reply = ask_with(
        "POST",
        "/agent",
        None,
        "X-Vjproj-Forwarded: 1\r\nOrigin: http://evil.example\r\n",
    );

    assert_eq!(reply.status, 403);
}

#[test]
fn machines_cannot_be_chained_into_a_loop() {
    let reply = ask("GET", "/at/mini/at/main/state", Some(TOKEN));

    assert_eq!(reply.status, 400);
    assert!(reply.body.contains("chained"), "got {}", reply.body);
}

#[test]
fn the_page_is_served_at_the_root() {
    let reply = ask("GET", "/", Some(TOKEN));
    assert_eq!(reply.status, 200);
    assert!(reply.body.contains("<!doctype html>"));
}

#[test]
fn an_unknown_route_is_a_plain_miss() {
    assert_eq!(ask("GET", "/nowhere", Some(TOKEN)).status, 404);
    assert_eq!(ask("POST", "/state", Some(TOKEN)).status, 404);
}

#[test]
fn a_pane_that_is_not_a_number_never_reaches_tmux() {
    assert_eq!(ask("POST", "/pane/abc/close", Some(TOKEN)).status, 400);
    assert_eq!(ask("GET", "/pane/abc/out", Some(TOKEN)).status, 400);
    assert_eq!(
        ask("GET", "/pane/..%2f..%2fetc/in", Some(TOKEN)).status,
        400
    );
}

#[test]
fn a_terminal_is_only_handed_over_to_a_real_websocket() {
    let reply = ask("GET", "/pane/1/out", Some(TOKEN));
    assert_eq!(reply.status, 400);
    assert!(reply.body.contains("not a websocket"), "{}", reply.body);
}

#[test]
fn a_working_tree_page_wins_but_generated_assets_still_fall_back() {
    let built = tempfile::tempdir().unwrap().keep();
    std::fs::write(built.join("index.html"), b"built").unwrap();
    std::fs::write(built.join("theme.css"), b":root{--bg:#181818}").unwrap();

    let editing = tempfile::tempdir().unwrap().keep();
    std::fs::write(editing.join("index.html"), b"edited").unwrap();

    let servers = http::bind(Ipv4Addr::LOCALHOST, 0).unwrap();
    let port = servers[0].server_addr().to_ip().unwrap().port();
    let serving = Serving {
        dirs: vjproj::paths::Dirs {
            runtime: built.clone(),
            data: built.clone(),
        },
        latest: std::sync::Arc::new(std::sync::Mutex::new(None)),
        token: TOKEN.into(),
        www: built,
        editing: Some(editing),
        port,
        peers: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
        devices: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
        trust: vjproj::auth::Trust::nobody(),
        shells: vjproj::shells::Untouched::new(),
        attaching: vjproj::attach::Attached::new(),
    };
    thread::spawn(move || http::serve(servers, serving));

    let get = |path: &str| {
        let mut stream = TcpStream::connect((Ipv4Addr::LOCALHOST, port)).unwrap();
        write!(
            stream,
            "GET {path} HTTP/1.1\r\nHost: x\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
        )
        .unwrap();
        let mut raw = String::new();
        stream.read_to_string(&mut raw).unwrap();
        raw.split_once("\r\n\r\n")
            .map(|(_, b)| b.to_owned())
            .unwrap()
    };

    assert_eq!(get("/"), "edited", "the working tree page must win");
    assert_eq!(
        get("/theme.css"),
        ":root{--bg:#181818}",
        "a generated asset absent from the working tree must fall back to the build"
    );
}
