use vjproj::auth;
use vjproj::http::{same_origin, split_url, token_in};
use vjproj::paths::Dirs;
use vjproj::tailnet;

fn scratch() -> Dirs {
    let runtime = tempfile::tempdir().unwrap().keep();
    let data = runtime.join("data");
    std::fs::create_dir_all(&data).unwrap();
    Dirs { runtime, data }
}

#[test]
fn a_token_is_minted_once_and_then_reused() {
    let dirs = scratch();
    let first = auth::token(&dirs).unwrap();
    let second = auth::token(&dirs).unwrap();

    assert_eq!(first, second);
    assert_eq!(first.len(), 64);
    assert!(first.chars().all(|c| c.is_ascii_hexdigit()));
}

#[test]
fn two_machines_never_mint_the_same_token() {
    assert_ne!(
        auth::token(&scratch()).unwrap(),
        auth::token(&scratch()).unwrap()
    );
}

#[test]
fn only_the_exact_token_opens_the_door() {
    assert!(auth::matches("abc123", Some("abc123")));
    assert!(!auth::matches("abc123", Some("abc124")));
    assert!(!auth::matches("abc123", Some("abc12")));
    assert!(!auth::matches("abc123", Some("")));
    assert!(!auth::matches("abc123", None));
}

#[test]
fn a_token_arrives_by_header_or_by_query() {
    assert_eq!(auth::presented(Some("Bearer abc"), None), Some("abc"));
    assert_eq!(auth::presented(None, Some("abc")), Some("abc"));
    assert_eq!(auth::presented(Some("Basic abc"), Some("xyz")), Some("xyz"));
    assert_eq!(auth::presented(None, None), None);
}

#[test]
fn a_query_string_gives_up_its_token() {
    let (path, query) = split_url("/state?token=abc&x=1");
    assert_eq!(path, "/state");
    assert_eq!(token_in(query), Some("abc"));

    let (path, query) = split_url("/state");
    assert_eq!(path, "/state");
    assert_eq!(token_in(query), None);
}

#[test]
fn our_own_page_is_the_only_origin_allowed_to_act() {
    let us = Some("100.100.0.1:8422");

    assert!(same_origin(Some("http://100.100.0.1:8422"), us));
    assert!(same_origin(None, us), "a plain client sends no origin");
}

#[test]
fn the_page_behind_the_tailnet_certificate_is_still_our_own() {
    let us = Some("main.example.ts.net");

    assert!(same_origin(Some("https://main.example.ts.net"), us));
    assert!(!same_origin(Some("https://mini.example.ts.net"), us));
}

#[test]
fn a_page_on_another_site_can_never_drive_this_machine() {
    let us = Some("100.100.0.1:8422");

    for origin in [
        "http://evil.example",
        "https://evil.example",
        "http://100.100.0.1:9999",
        "http://100.100.0.2:8422",
        "null",
        "",
        "http://100.100.0.1:8422.evil.example",
    ] {
        assert!(
            !same_origin(Some(origin), us),
            "{origin:?} must not be able to act on our behalf"
        );
    }
}

#[test]
fn an_origin_without_a_host_to_compare_against_is_refused() {
    assert!(!same_origin(Some("http://100.100.0.1:8422"), None));
    assert!(!same_origin(Some("http://100.100.0.1:8422"), Some("")));
}

#[test]
fn only_addresses_on_the_tailnet_are_listened_on() {
    assert!(tailnet::is_tailnet("100.64.0.1".parse().unwrap()));
    assert!(tailnet::is_tailnet("100.127.255.255".parse().unwrap()));
    assert!(!tailnet::is_tailnet("100.128.0.1".parse().unwrap()));
    assert!(!tailnet::is_tailnet("100.63.255.255".parse().unwrap()));
    assert!(!tailnet::is_tailnet("192.168.1.5".parse().unwrap()));
    assert!(!tailnet::is_tailnet("127.0.0.1".parse().unwrap()));
}

#[test]
fn the_tailnet_address_is_picked_out_of_whatever_tailscale_prints() {
    assert_eq!(
        tailnet::parse_address("192.168.1.5\n100.101.102.103\n"),
        Some("100.101.102.103".parse().unwrap())
    );
    assert_eq!(tailnet::parse_address(""), None);
    assert_eq!(tailnet::parse_address("192.168.1.5\n"), None);
}

#[test]
fn a_process_stat_line_gives_up_its_parent() {
    assert_eq!(
        vjproj::agents::parse_parent("42 (some cmd) S 17 42 42 0 -1 4194304 100 0"),
        Some(17)
    );
    assert_eq!(
        vjproj::agents::parse_parent("42 (weird ) name) S 19 42 42 0"),
        Some(19)
    );
    assert_eq!(vjproj::agents::parse_parent("nonsense"), None);
}

#[test]
fn a_chain_starts_at_the_process_itself() {
    let chain = vjproj::panes::chain(std::process::id());
    assert_eq!(chain[0], std::process::id());
    assert!(chain.len() > 1, "a test process always has a parent");
}

#[test]
fn the_token_outlives_a_reboot() {
    let runtime = tempfile::tempdir().unwrap();
    let data = tempfile::tempdir().unwrap();
    let dirs = vjproj::paths::Dirs {
        runtime: runtime.path().to_path_buf(),
        data: data.path().to_path_buf(),
    };

    let minted = vjproj::auth::token(&dirs).unwrap();

    assert!(
        dirs.token().starts_with(data.path()),
        "the token must live where a reboot cannot wipe it, not in {}",
        dirs.token().display()
    );
    assert_eq!(
        vjproj::auth::token(&dirs).unwrap(),
        minted,
        "a second read must hand back the same token, not mint a new one"
    );
}
