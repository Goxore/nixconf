use std::path::{Path, PathBuf};
use std::process::{Command, Output};

const IDENTITY_TOML: &str = r#"
[roots]
standalone = ["~/nixconf"]
containers = ["~/Projects"]
markers = [".vjenv-root"]

[identities.goxore]
name = "Yurii"
email = "yurii@goxore.com"
ssh_key = "~/.ssh/primary"

[identities.vimjoyer]
name = "Vimjoyer"
email = "vimjoyer@gmail.com"
"#;

struct Sandbox {
    _tmp: tempfile::TempDir,
    home: PathBuf,
}

impl Sandbox {
    fn new() -> Self {
        let tmp = tempfile::tempdir().unwrap();
        let home = tmp.path().join("home");
        std::fs::create_dir_all(home.join(".config/vjenv")).unwrap();
        std::fs::create_dir_all(home.join("Projects/secretspec/src")).unwrap();
        std::fs::create_dir_all(home.join("nixconf")).unwrap();
        std::fs::create_dir_all(home.join("elsewhere")).unwrap();
        std::fs::write(home.join(".config/vjenv/identity.toml"), IDENTITY_TOML).unwrap();
        Self { _tmp: tmp, home }
    }

    fn run(&self, cwd: &Path, args: &[&str]) -> Output {
        Command::new(env!("CARGO_BIN_EXE_vjenv"))
            .args(args)
            .current_dir(cwd)
            .env_clear()
            .env("HOME", &self.home)
            .env("PATH", std::env::var("PATH").unwrap_or_default())
            .env("XDG_CONFIG_HOME", self.home.join(".config"))
            .env("XDG_STATE_HOME", self.home.join(".local/state"))
            .env("XDG_DATA_HOME", self.home.join(".local/share"))
            .env("XDG_RUNTIME_DIR", self.home.join(".run"))
            .env("VJENV_SYSTEM", "x86_64-linux")
            .output()
            .expect("vjenv should be runnable")
    }

    fn ok(&self, cwd: &Path, args: &[&str]) -> String {
        let out = self.run(cwd, args);
        assert!(
            out.status.success(),
            "vjenv {args:?} failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        String::from_utf8(out.stdout).unwrap()
    }

    fn project(&self) -> PathBuf {
        self.home.join("Projects/secretspec")
    }
}

fn assert_parses(text: &str, shell: &str, syntax_flag: &str) {
    let dir = tempfile::tempdir().unwrap();
    let script = dir.path().join("emitted");
    std::fs::write(&script, text).unwrap();

    let Ok(out) = Command::new(shell).arg(syntax_flag).arg(&script).output() else {
        eprintln!("skipping {shell} syntax check: not installed");
        return;
    };
    assert!(
        out.status.success(),
        "{shell} rejected the emitted code:\n{text}\n{}",
        String::from_utf8_lossy(&out.stderr)
    );
}

#[test]
fn resolve_reports_the_container_child() {
    let s = Sandbox::new();
    let out = s.ok(&s.project().join("src"), &["resolve"]);
    assert_eq!(out.trim(), s.project().to_string_lossy());
}

#[test]
fn resolve_fails_outside_a_project_with_a_useful_message() {
    let s = Sandbox::new();
    let out = s.run(&s.home.join("elsewhere"), &["resolve"]);
    assert!(!out.status.success());
    let err = String::from_utf8_lossy(&out.stderr);
    assert!(err.contains("not inside a known project"), "{err}");
    assert!(err.contains("identity.toml"), "{err}");
}

#[test]
fn an_unassigned_project_emits_a_complete_set_of_unsets() {
    let s = Sandbox::new();
    let out = s.ok(&s.project(), &["env", "posix"]);
    for var in [
        "VJENV_IDENTITY",
        "VJENV_ROOT",
        "GIT_CONFIG_COUNT",
        "GIT_SSH_COMMAND",
        "GH_CONFIG_DIR",
        "JJ_CONFIG",
    ] {
        assert!(out.contains(&format!("unset {var}\n")), "{var} not cleared:\n{out}");
    }
    assert!(!out.contains("export "), "nothing should be exported:\n{out}");
    assert_parses(&out, "sh", "-n");
}

#[test]
fn an_assigned_project_emits_the_full_identity() {
    let s = Sandbox::new();
    let p = s.project();
    s.ok(&p, &["assign", "--identity", "goxore"]);

    let out = s.ok(&p, &["env", "posix"]);
    let expected = format!(
        "export VJENV_IDENTITY='goxore'\n\
         export VJENV_ROOT='{root}'\n\
         unset VJENV_PINNED\n\
         export GIT_CONFIG_COUNT='3'\n\
         export GIT_CONFIG_KEY_0='user.name'\n\
         export GIT_CONFIG_VALUE_0='Yurii'\n\
         export GIT_CONFIG_KEY_1='user.email'\n\
         export GIT_CONFIG_VALUE_1='yurii@goxore.com'\n\
         export GIT_CONFIG_KEY_2='core.sshCommand'\n\
         export GIT_CONFIG_VALUE_2='ssh -i {home}/.ssh/primary -o IdentitiesOnly=yes'\n\
         export GIT_SSH_COMMAND='ssh -i {home}/.ssh/primary -o IdentitiesOnly=yes'\n\
         export GH_CONFIG_DIR='{home}/.local/share/vjenv/goxore/gh'\n\
         export JJ_CONFIG='{home}/.run/vjenv/goxore.jj.toml'\n",
        root = p.display(),
        home = s.home.display(),
    );
    assert_eq!(out, expected);
    assert_parses(&out, "sh", "-n");
}

#[test]
fn the_jj_fragment_is_written_when_the_identity_is_emitted() {
    let s = Sandbox::new();
    s.ok(&s.project(), &["assign", "--identity", "goxore"]);
    s.ok(&s.project(), &["env", "posix"]);

    let fragment = s.home.join(".run/vjenv/goxore.jj.toml");
    let text = std::fs::read_to_string(&fragment).expect("fragment should exist");
    let parsed: toml::Value = toml::from_str(&text).unwrap();
    assert_eq!(parsed["user"]["email"].as_str(), Some("yurii@goxore.com"));
}

#[test]
fn switching_to_a_keyless_identity_clears_the_key() {
    let s = Sandbox::new();
    let p = s.project();
    s.ok(&p, &["assign", "--identity", "vimjoyer"]);
    let out = s.ok(&p, &["env", "posix"]);
    assert!(out.contains("export GIT_CONFIG_COUNT='2'\n"), "{out}");
    assert!(out.contains("unset GIT_SSH_COMMAND\n"), "{out}");
    assert!(out.contains("unset GIT_CONFIG_KEY_2\n"), "{out}");
}

#[test]
fn fish_output_is_valid_fish() {
    let s = Sandbox::new();
    s.ok(&s.project(), &["assign", "--identity", "goxore"]);
    let out = s.ok(&s.project(), &["env", "fish"]);
    assert!(out.contains("set -gx VJENV_IDENTITY 'goxore'\n"), "{out}");
    assert!(out.contains("set -e VJENV_PINNED\n"), "{out}");
    assert_parses(&out, "fish", "-n");
}

#[test]
fn shellinit_is_valid_fish_and_defines_the_hook() {
    let s = Sandbox::new();
    let out = s.ok(&s.home, &["shellinit", "fish"]);
    assert!(out.contains("--on-variable PWD"), "{out}");
    assert_parses(&out, "fish", "-n");
}

#[test]
fn a_dev_environment_is_offered_once_and_remembered_when_denied() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("flake.nix"), "{}").unwrap();
    s.ok(&p, &["assign", "--identity", "goxore"]);

    let offered = s.ok(&p, &["env", "fish"]);
    assert!(
        offered.contains(&format!("set -g __vjenv_env_pending '{}'", p.display())),
        "{offered}"
    );

    s.ok(&p, &["deny"]);
    let after = s.ok(&p, &["env", "fish"]);
    assert!(!after.contains("__vjenv_env_pending"), "deny must be remembered:\n{after}");
}

#[test]
fn no_devshell_suppresses_the_dev_environment_section() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("flake.nix"), "{}").unwrap();
    let out = s.ok(&p, &["env", "fish", "--no-devshell"]);
    assert!(!out.contains("__vjenv_env_pending"), "{out}");
}

#[test]
fn use_emits_an_override_and_clear_removes_it() {
    let s = Sandbox::new();
    assert_eq!(
        s.ok(&s.project(), &["use", "goxore", "--shell", "fish"]),
        "set -gx VJENV_OVERRIDE 'goxore'\n"
    );
    assert_eq!(
        s.ok(&s.project(), &["use", "--clear", "--shell", "posix"]),
        "unset VJENV_OVERRIDE\n"
    );
    let bad = s.run(&s.project(), &["use", "nobody"]);
    assert!(!bad.status.success());
    assert!(String::from_utf8_lossy(&bad.stderr).contains("no such identity"));
}

#[test]
fn assign_rejects_unknown_identities() {
    let s = Sandbox::new();
    let p = s.project();

    let bad_id = s.run(&p, &["assign", "--identity", "ghost"]);
    assert!(!bad_id.status.success());
    assert!(String::from_utf8_lossy(&bad_id.stderr).contains("no such identity 'ghost'"));
}

#[test]
fn assign_records_the_identity() {
    let s = Sandbox::new();
    let p = s.project();
    s.ok(&p, &["assign", "--identity", "goxore"]);

    let text = std::fs::read_to_string(s.home.join(".local/state/vjenv/projects.toml")).unwrap();
    let reg: toml::Value = toml::from_str(&text).unwrap();
    let entry = &reg[p.to_string_lossy().as_ref()];
    assert_eq!(entry["identity"].as_str(), Some("goxore"));
}

#[test]
fn vjenv_no_longer_knows_about_agents() {
    let s = Sandbox::new();
    let gone = s.run(&s.project(), &["tool", "claude"]);
    assert!(
        !gone.status.success(),
        "agent config dirs belong to the wrappers now, not vjenv"
    );
}

#[test]
fn status_explains_an_unassigned_project() {
    let s = Sandbox::new();
    let out = s.ok(&s.project(), &["status"]);
    assert!(out.contains("container"), "{out}");
    assert!(out.contains("unassigned"), "{out}");
}

#[test]
fn gc_drops_entries_for_directories_that_are_gone() {
    let s = Sandbox::new();
    let doomed = s.home.join("Projects/temporary");
    std::fs::create_dir_all(&doomed).unwrap();
    s.ok(&doomed, &["assign", "--identity", "goxore"]);
    s.ok(&s.project(), &["assign", "--identity", "vimjoyer"]);
    std::fs::remove_dir_all(&doomed).unwrap();

    let dry = s.ok(&s.home, &["gc", "--dry-run"]);
    assert!(dry.contains(&doomed.to_string_lossy().to_string()), "{dry}");
    assert!(dry.contains("nothing removed"), "{dry}");
    let still_there = std::fs::read_to_string(s.home.join(".local/state/vjenv/projects.toml")).unwrap();
    assert!(still_there.contains("temporary"));

    s.ok(&s.home, &["gc"]);
    let after = std::fs::read_to_string(s.home.join(".local/state/vjenv/projects.toml")).unwrap();
    assert!(!after.contains("temporary"), "{after}");
    assert!(after.contains("secretspec"), "{after}");
}

#[test]
fn exec_runs_a_command_with_the_identity_applied() {
    let s = Sandbox::new();
    let p = s.project();
    s.ok(&p, &["assign", "--identity", "goxore"]);
    let out = s.ok(&p, &["exec", "sh", "-c", "printf %s \"$VJENV_IDENTITY\""]);
    assert_eq!(out, "goxore");
}

#[test]
fn a_marker_file_makes_an_arbitrary_directory_a_project() {
    let s = Sandbox::new();
    let dir = s.home.join("elsewhere/thing");
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join(".vjenv-root"), "").unwrap();
    assert_eq!(s.ok(&dir, &["resolve"]).trim(), dir.to_string_lossy());
}

#[test]
fn completions_are_produced_for_fish() {
    let s = Sandbox::new();
    let out = s.ok(&s.home, &["completions", "fish"]);
    assert!(out.contains("vjenv"), "{out}");
    assert!(out.contains("assign"), "{out}");
}
