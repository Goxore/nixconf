use vjproj::peers::{self, PeerView};
use vjproj::tailnet;

const STATUS: &str = r#"{
  "Self": {
    "HostName": "main",
    "DNSName": "main.example.ts.net.",
    "TailscaleIPs": ["100.100.0.1", "fd7a:115c:a1e0::1"],
    "UserID": 2222222222222222,
    "Online": true
  },
  "Peer": {
    "nodekey:aaa": {
      "HostName": "mini",
      "DNSName": "mini.example.ts.net.",
      "TailscaleIPs": ["100.100.0.2"],
      "UserID": 2222222222222222,
      "Online": true
    },
    "nodekey:bbb": {
      "HostName": "Pixel 8a",
      "DNSName": "pixel-8a.example.ts.net.",
      "TailscaleIPs": ["100.100.0.3"],
      "UserID": 2222222222222222,
      "Online": true
    },
    "nodekey:ccc": {
      "HostName": "asleep",
      "DNSName": "asleep.example.ts.net.",
      "TailscaleIPs": ["100.100.0.4"],
      "UserID": 2222222222222222,
      "Online": false
    },
    "nodekey:ddd": {
      "HostName": "someone-else",
      "DNSName": "someone-else.example.ts.net.",
      "TailscaleIPs": ["100.100.0.5"],
      "UserID": 1111111111111111,
      "Online": true
    },
    "nodekey:eee": {
      "HostName": "BROTHER-PC",
      "DNSName": "brother-pc.example.ts.net.",
      "TailscaleIPs": ["100.100.0.6"],
      "UserID": 2222222222222222,
      "Online": true
    }
  },
  "User": {
    "2222222222222222": { "LoginName": "example@example.com" }
  }
}"#;

fn listed(names: &[&str]) -> Vec<String> {
    names.iter().map(|name| (*name).to_owned()).collect()
}

fn hosts(raw: &str, allowed: &[&str]) -> Vec<String> {
    tailnet::parse_peers(raw, &listed(allowed))
        .into_iter()
        .map(|peer| peer.host)
        .collect()
}

#[test]
fn only_machines_we_named_are_peers() {
    assert_eq!(
        hosts(STATUS, &["mini", "pixel-8a"]),
        vec!["mini", "pixel-8a"]
    );
    assert_eq!(hosts(STATUS, &["mini"]), vec!["mini"]);
}

#[test]
fn a_machine_we_never_named_is_left_alone() {
    let every = hosts(STATUS, &["mini", "pixel-8a", "asleep", "someone-else"]);

    assert!(
        !every.contains(&"brother-pc".to_owned()),
        "an unlisted machine on the tailnet must never become a peer"
    );
    assert!(hosts(STATUS, &[]).is_empty());
}

#[test]
fn a_machine_is_named_by_its_dns_label_not_its_pretty_hostname() {
    let found = tailnet::parse_peers(STATUS, &listed(&["pixel-8a"]));

    assert_eq!(found.len(), 1);
    assert_eq!(found[0].host, "pixel-8a");
    assert_eq!(found[0].address.to_string(), "100.100.0.3");
}

#[test]
fn a_peer_carries_the_tailnet_address_we_reach_it_on() {
    let found = tailnet::parse_peers(STATUS, &listed(&["mini"]));
    let mini = found.iter().find(|peer| peer.host == "mini").unwrap();

    assert_eq!(mini.address.to_string(), "100.100.0.2");
    assert!(tailnet::is_tailnet(mini.address));
}

#[test]
fn a_hostname_falls_back_when_there_is_no_dns_name() {
    assert_eq!(tailnet::label("", "fallback"), "fallback");
    assert_eq!(tailnet::label("mini.example.ts.net.", "mini"), "mini");
}

#[test]
fn our_own_login_is_read_from_the_user_table() {
    assert_eq!(
        tailnet::parse_own_login(STATUS).as_deref(),
        Some("example@example.com")
    );
}

#[test]
fn a_whois_answer_yields_both_the_owner_and_the_machine() {
    let raw = r#"{
      "Node": {"Name": "mini.example.ts.net."},
      "UserProfile": {"LoginName": "example@example.com"}
    }"#;
    let who = tailnet::parse_identity(raw).unwrap();

    assert_eq!(who.login, "example@example.com");
    assert_eq!(who.host, "mini");
}

#[test]
fn nonsense_from_tailscale_yields_no_peers_rather_than_a_panic() {
    let every = listed(&["mini"]);

    assert!(tailnet::parse_peers("not json at all", &every).is_empty());
    assert!(tailnet::parse_peers("{}", &every).is_empty());
    assert_eq!(tailnet::parse_own_login("{}"), None);
    assert_eq!(tailnet::parse_identity("{}"), None);
}

const FRONTED: &str = r#"{
  "TCP": { "443": { "HTTPS": true } },
  "Web": {
    "main.example.ts.net:443": {
      "Handlers": { "/": { "Proxy": "http://127.0.0.1:8422" } }
    }
  }
}"#;

#[test]
fn a_served_name_is_read_back_when_https_fronts_our_port() {
    assert_eq!(
        tailnet::parse_fronted(FRONTED, 8422).as_deref(),
        Some("main.example.ts.net")
    );
}

#[test]
fn a_proxy_to_another_port_is_not_ours_to_advertise() {
    assert_eq!(tailnet::parse_fronted(FRONTED, 9999), None);
}

#[test]
fn a_plain_http_front_never_passes_for_a_secure_one() {
    let plain = r#"{
      "TCP": { "80": { "HTTP": true } },
      "Web": {
        "main.example.ts.net:80": {
          "Handlers": { "/": { "Proxy": "http://127.0.0.1:8422" } }
        }
      }
    }"#;

    assert_eq!(tailnet::parse_fronted(plain, 8422), None);
}

#[test]
fn an_https_port_we_cannot_name_in_a_bare_url_is_left_alone() {
    let odd = r#"{
      "TCP": { "8443": { "HTTPS": true } },
      "Web": {
        "main.example.ts.net:8443": {
          "Handlers": { "/": { "Proxy": "http://127.0.0.1:8422" } }
        }
      }
    }"#;

    assert_eq!(tailnet::parse_fronted(odd, 8422), None);
}

#[test]
fn a_path_on_the_proxy_target_still_reveals_the_port() {
    let mounted = r#"{
      "TCP": { "443": { "HTTPS": true } },
      "Web": {
        "main.example.ts.net:443": {
          "Handlers": { "/": { "Proxy": "http://127.0.0.1:8422/deep" } }
        }
      }
    }"#;

    assert_eq!(
        tailnet::parse_fronted(mounted, 8422).as_deref(),
        Some("main.example.ts.net")
    );
}

#[test]
fn nothing_served_yet_means_no_secure_address_to_print() {
    assert_eq!(tailnet::parse_fronted("{}", 8422), None);
    assert_eq!(tailnet::parse_fronted("null", 8422), None);
    assert_eq!(tailnet::parse_fronted("not json at all", 8422), None);
}

fn view(host: &str, address: &str) -> PeerView {
    PeerView {
        host: host.to_owned(),
        address: address.to_owned(),
        state: serde_json::json!({}),
    }
}

#[test]
fn a_machine_is_located_by_name_among_the_peers_we_reached() {
    let known = vec![view("mini", "100.100.0.2"), view("shed", "100.100.0.7")];

    assert_eq!(
        peers::located(&known, "mini").map(|address| address.to_string()),
        Some("100.100.0.2".to_owned())
    );
    assert_eq!(peers::located(&known, "nowhere"), None);
}

#[test]
fn a_project_shell_has_a_stable_session_name_so_it_is_reattached() {
    assert_eq!(vjproj::tmux::session_for(1), "vjproj-1");
    assert_eq!(vjproj::tmux::session_for(9), "vjproj-9");
    assert_ne!(vjproj::tmux::session_for(1), vjproj::tmux::session_for(2));
}

#[test]
fn a_session_name_never_confuses_tmux_targeting() {
    for project in 1..=9u8 {
        let name = vjproj::tmux::session_for(project);
        assert!(!name.contains(':'), "a colon would read as a window");
        assert!(!name.contains('.'), "a dot would read as a pane");
        assert!(!name.contains(' '));
    }
}

#[test]
fn the_shell_refuses_a_directory_outside_home() {
    let outside = std::path::Path::new("/etc");

    let refused = vjproj::tmux::shell(outside, 1);
    assert!(refused.is_err(), "a shell outside home must be refused");
}

#[test]
fn a_directory_that_climbs_out_of_home_is_refused() {
    let home = vjproj::paths::home();

    assert!(vjproj::paths::home_dir(&home).is_ok());
    assert!(
        vjproj::paths::home_dir(&home.join("../../../../../../etc")).is_err(),
        "dot-dot must not escape home"
    );
}

#[test]
fn the_shell_refuses_a_project_that_does_not_exist() {
    let home = vjproj::paths::home();

    assert!(vjproj::tmux::shell(&home, 0).is_err());
    assert!(vjproj::tmux::shell(&home, 200).is_err());
}

#[test]
fn only_fonts_are_worth_keeping_in_the_phones_cache() {
    assert!(vjproj::http::keeps("regular.woff2"));
    assert!(vjproj::http::keeps("icons.woff2"));
    assert!(!vjproj::http::keeps("index.html"));
    assert!(!vjproj::http::keeps("icons.json"));
    assert!(!vjproj::http::keeps("theme.css"));
}

#[test]
fn the_terminal_font_is_served_like_the_icons_are() {
    let named = vjproj::http::asset_named("/regular.woff2");

    assert_eq!(named.map(|(_, kind)| kind), Some("font/woff2"));
    assert!(vjproj::http::public("GET", "/regular.woff2"));
    assert!(!vjproj::http::public("POST", "/regular.woff2"));
}

#[test]
fn an_endpoint_points_at_the_same_port_on_the_other_machine() {
    let address = "100.100.0.2".parse().unwrap();

    assert_eq!(
        peers::endpoint(address, 8422, "/pane/4/keys"),
        "http://100.100.0.2:8422/pane/4/keys"
    );
}

#[test]
fn a_directory_typed_on_the_phone_is_read_from_home() {
    let home = vjproj::paths::home();

    assert_eq!(vjproj::paths::rooted(std::path::Path::new("~")), home);
    assert_eq!(
        vjproj::paths::rooted(std::path::Path::new("~/nixconf")),
        home.join("nixconf")
    );
    assert_eq!(
        vjproj::paths::rooted(std::path::Path::new("nixconf")),
        home.join("nixconf")
    );
    assert_eq!(
        vjproj::paths::rooted(std::path::Path::new("/etc")),
        std::path::PathBuf::from("/etc")
    );
}

#[test]
fn a_kept_font_is_checked_again_after_every_rebuild() {
    let before = vjproj::http::built_stamp(std::path::Path::new("/nix/store/aaa-vjproj-www"));
    let after = vjproj::http::built_stamp(std::path::Path::new("/nix/store/bbb-vjproj-www"));

    assert_eq!(before, "\"aaa-vjproj-www\"");
    assert_ne!(before, after);
}
