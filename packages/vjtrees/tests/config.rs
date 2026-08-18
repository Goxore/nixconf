use vjtrees::config::{Config, Require};

const MINIMAL: &str = r#"
[project]
trunk = "trunk"

[open]
command = ["nvim", "{workspace}"]
"#;

fn error_of(text: &str) -> String {
    let error = Config::parse(text).expect_err("expected this config to be rejected");
    format!("{error:#}")
}

#[test]
fn a_minimal_config_parses_and_fills_in_defaults() {
    let config = Config::parse(MINIMAL).expect("parses");

    assert_eq!(config.project.trunk, "trunk");
    assert_eq!(config.project.trunk_workspace, "default");
    assert_eq!(config.limits.ancestor_scan, 50);
    assert_eq!(config.backup.require, Require::Irreversible);
    assert!(!config.backup.prune, "pruning must never be the default");
    assert!(config.server.is_none());
    assert!(config.setup.is_none());
    assert!(config.check.is_none());
}

#[test]
fn an_empty_marker_is_an_error_that_points_at_init() {
    let message = error_of("   \n  \n");
    assert!(message.contains("vjtrees init"), "got: {message}");
}

#[test]
fn a_missing_trunk_is_named_in_the_error() {
    let message = error_of(
        r#"
[open]
command = ["nvim"]
"#,
    );
    assert!(message.contains("project"), "got: {message}");
}

#[test]
fn a_missing_open_command_is_named_in_the_error() {
    let message = error_of(
        r#"
[project]
trunk = "trunk"
"#,
    );
    assert!(message.contains("open"), "got: {message}");
}

#[test]
fn an_unknown_key_is_rejected_rather_than_ignored() {
    let message = error_of(
        r#"
[project]
trunk = "trunk"
trunkk = "typo"

[open]
command = ["nvim"]
"#,
    );
    assert!(message.contains("trunkk"), "got: {message}");
}

#[test]
fn an_unknown_section_is_rejected_rather_than_ignored() {
    let message = error_of(
        r#"
[project]
trunk = "trunk"

[open]
command = ["nvim"]

[serverr]
command = ["bun"]
"#,
    );
    assert!(message.contains("serverr"), "got: {message}");
}

#[test]
fn a_wrong_type_is_rejected() {
    let message = error_of(
        r#"
[project]
trunk = 3

[open]
command = ["nvim"]
"#,
    );
    assert!(
        message.contains("trunk") || message.contains("string"),
        "got: {message}"
    );
}

#[test]
fn an_unknown_placeholder_is_rejected_and_the_known_ones_are_listed() {
    let message = error_of(
        r#"
[project]
trunk = "trunk"

[open]
command = ["nvim", "{wrokspace}"]
"#,
    );
    assert!(message.contains("wrokspace"), "got: {message}");
    assert!(message.contains("{workspace}"), "got: {message}");
}

#[test]
fn using_the_entry_placeholder_without_declaring_entry_is_rejected() {
    let message = error_of(
        r#"
[project]
trunk = "trunk"

[open]
command = ["nvim", "{entry}"]
"#,
    );
    assert!(message.contains("entry"), "got: {message}");
}

#[test]
fn declaring_entry_makes_the_placeholder_legal() {
    let config = Config::parse(
        r#"
[project]
trunk = "trunk"

[open]
command = ["nvim", "{entry}"]
entry = "video/video.vjc"
"#,
    )
    .expect("parses");

    assert_eq!(config.open.entry.as_deref(), Some("video/video.vjc"));
}

#[test]
fn a_trunk_that_is_a_path_is_rejected() {
    let message = error_of(
        r#"
[project]
trunk = "nested/trunk"

[open]
command = ["nvim"]
"#,
    );
    assert!(message.contains("trunk"), "got: {message}");
}

#[test]
fn a_server_section_without_ports_is_rejected() {
    let message = error_of(
        r#"
[project]
trunk = "trunk"

[open]
command = ["nvim"]

[server]
command = ["bun", "dev"]
"#,
    );
    assert!(message.contains("ports"), "got: {message}");
}

#[test]
fn a_full_config_round_trips_every_section() {
    let config = Config::parse(
        r#"
[project]
trunk = "vjcanvas"
trunk-workspace = "default"

[open]
command = ["nvim", "-c", "luafile {workspace}/vjc.lua", "{entry}"]
cwd = "video"
entry = "video/video.vjc"

[setup]
command = ["bun", "install"]
when-missing = "node_modules"
when-newer = "package.json"

[server]
command = ["bun", "dev"]
ports = [5173]
wait-ports = [5174]
wait-if-present = "vite/lsp.ts"

[check]
command = ["bun", "run", "tsc", "--noEmit"]

[paths]
owned = ["video/"]
fragile = ["src/dsl/"]

[backup]
excludes = ["node_modules"]
keep-last = 10
keep-daily = 7
prune = true
require = "always"

[limits]
ancestor-scan = 12
"#,
    )
    .expect("parses");

    assert_eq!(config.open.cwd.as_deref(), Some("video"));
    assert_eq!(
        config.setup.unwrap().when_missing.as_deref(),
        Some("node_modules")
    );
    assert_eq!(config.server.as_ref().unwrap().ports, vec![5173]);
    assert_eq!(config.server.unwrap().wait_ports, vec![5174]);
    assert_eq!(config.check.unwrap().command.len(), 4);
    assert_eq!(config.paths.owned, vec!["video/".to_string()]);
    assert_eq!(config.backup.keep_last, 10);
    assert_eq!(config.backup.require, Require::Always);
    assert_eq!(config.limits.ancestor_scan, 12);
}
