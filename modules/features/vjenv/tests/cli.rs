use std::path::{Path, PathBuf};
use std::process::{Command, Output};

const IDENTITY_TOML: &str = r#"
[roots]
standalone = ["~/nixconf"]
containers = ["~/Projects"]
markers = [".vjenv-root"]

[identities.goxore]
name = "Yurii"
email = "goxore@example.com"
ssh_key = "~/.ssh/primary"

[identities.vimjoyer]
name = "Vimjoyer"
email = "vimjoyer@example.com"
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
        std::fs::create_dir_all(home.join("bin")).unwrap();
        std::fs::write(home.join(".config/vjenv/identity.toml"), IDENTITY_TOML).unwrap();
        Self { _tmp: tmp, home }
    }

    fn path(&self) -> String {
        format!(
            "{}:{}",
            self.home.join("bin").display(),
            std::env::var("PATH").unwrap_or_default()
        )
    }

    fn fake(&self, name: &str, script: &str) {
        use std::os::unix::fs::PermissionsExt;
        let file = self.home.join("bin").join(name);
        std::fs::write(&file, format!("#!/bin/sh\n{script}")).unwrap();
        std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o755)).unwrap();
    }

    fn run(&self, cwd: &Path, args: &[&str]) -> Output {
        self.with_env(cwd, args, &[])
    }

    fn with_env(&self, cwd: &Path, args: &[&str], extra: &[(&str, &str)]) -> Output {
        let mut cmd = Command::new(env!("CARGO_BIN_EXE_vjenv"));
        cmd.args(args)
            .current_dir(cwd)
            .env_clear()
            .env("HOME", &self.home)
            .env("PATH", self.path())
            .env("XDG_CONFIG_HOME", self.home.join(".config"))
            .env("XDG_STATE_HOME", self.home.join(".local/state"))
            .env("XDG_DATA_HOME", self.home.join(".local/share"))
            .env("XDG_RUNTIME_DIR", self.home.join(".run"))
            .env("VJENV_SYSTEM", "x86_64-linux");
        for (k, v) in extra {
            cmd.env(k, v);
        }
        cmd.output().expect("vjenv should be runnable")
    }

    fn ok_with_env(&self, cwd: &Path, args: &[&str], extra: &[(&str, &str)]) -> String {
        let out = self.with_env(cwd, args, extra);
        assert!(
            out.status.success(),
            "vjenv {args:?} failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        String::from_utf8(out.stdout).unwrap()
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
fn status_reports_the_container_child() {
    let s = Sandbox::new();
    let out = s.ok(&s.project().join("src"), &["status"]);
    assert!(
        out.contains(&format!("root     : {} (container)", s.project().display())),
        "{out}"
    );
}

#[test]
fn assign_fails_outside_a_project_with_a_useful_message() {
    let s = Sandbox::new();
    let out = s.run(
        &s.home.join("elsewhere"),
        &["assign", "--identity", "goxore"],
    );
    assert!(!out.status.success());
    let err = String::from_utf8_lossy(&out.stderr);
    assert!(err.contains("not inside a known project"), "{err}");
    assert!(err.contains("identity.toml"), "{err}");
}

fn without_path(text: &str) -> String {
    text.lines()
        .filter(|l| !l.starts_with("export PATH=") && !l.starts_with("set -gx PATH "))
        .map(|l| format!("{l}\n"))
        .collect()
}

#[test]
fn an_unassigned_project_clears_every_variable_that_is_set() {
    let s = Sandbox::new();
    let fragment = s.home.join(".run/vjenv/goxore.jj.toml");
    let fragment = fragment.to_str().unwrap();
    let set: Vec<(&str, &str)> = vec![
        ("VJENV_IDENTITY", "goxore"),
        ("VJENV_ROOT", "/somewhere"),
        ("GIT_CONFIG_COUNT", "3"),
        ("GIT_SSH_COMMAND", "ssh -i /k"),
        ("GH_CONFIG_DIR", "/d"),
        ("JJ_CONFIG", fragment),
    ];
    let out = s.ok_with_env(&s.project(), &["env", "posix"], &set);
    for (var, _) in &set {
        assert!(
            out.contains(&format!("unset {var}\n")),
            "{var} not cleared:\n{out}"
        );
    }
    assert!(
        !without_path(&out).contains("export "),
        "nothing but PATH should be exported:\n{out}"
    );
    assert_parses(&out, "sh", "-n");
}

#[test]
fn a_variable_that_is_already_absent_is_not_mentioned_again() {
    let s = Sandbox::new();
    let out = s.ok(&s.project(), &["env", "posix"]);
    assert!(
        !out.contains("unset VJENV_IDENTITY"),
        "an already-empty environment needs no instructions:\n{out}"
    );
}

#[test]
fn an_assigned_project_emits_the_full_identity() {
    let s = Sandbox::new();
    let p = s.project();
    s.ok(&p, &["assign", "--identity", "goxore"]);

    let out = without_path(&s.ok_with_env(&p, &["env", "posix"], &[("VJENV_PINNED", "1")]));
    let expected = format!(
        "export VJENV_IDENTITY='goxore'\n\
         export VJENV_ROOT='{root}'\n\
         unset VJENV_PINNED\n\
         export GIT_CONFIG_COUNT='3'\n\
         export GIT_CONFIG_KEY_0='user.name'\n\
         export GIT_CONFIG_VALUE_0='Yurii'\n\
         export GIT_CONFIG_KEY_1='user.email'\n\
         export GIT_CONFIG_VALUE_1='goxore@example.com'\n\
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
    assert_eq!(parsed["user"]["email"].as_str(), Some("goxore@example.com"));
}

#[test]
fn switching_to_a_keyless_identity_clears_the_key() {
    let s = Sandbox::new();
    let p = s.project();
    s.ok(&p, &["assign", "--identity", "vimjoyer"]);
    let out = s.ok_with_env(
        &p,
        &["env", "posix"],
        &[
            ("GIT_SSH_COMMAND", "ssh -i /previous -o IdentitiesOnly=yes"),
            ("GIT_CONFIG_KEY_2", "core.sshCommand"),
        ],
    );
    assert!(out.contains("export GIT_CONFIG_COUNT='2'\n"), "{out}");
    assert!(out.contains("unset GIT_SSH_COMMAND\n"), "{out}");
    assert!(out.contains("unset GIT_CONFIG_KEY_2\n"), "{out}");
}

#[test]
fn fish_output_is_valid_fish() {
    let s = Sandbox::new();
    s.ok(&s.project(), &["assign", "--identity", "goxore"]);
    let out = s.ok_with_env(&s.project(), &["env", "fish"], &[("VJENV_PINNED", "1")]);
    assert!(out.contains("set -gx VJENV_IDENTITY 'goxore'\n"), "{out}");
    assert!(out.contains("set -e VJENV_PINNED\n"), "{out}");
    assert_parses(&out, "fish", "-n");
}

#[test]
fn fish_receives_the_search_path_as_a_list() {
    let s = Sandbox::new();
    s.ok(&s.project(), &["assign", "--identity", "goxore"]);
    let out = s.ok_with_env(
        &s.project(),
        &["env", "fish"],
        &[("PATH", "/usr/bin:/bin:/usr/bin")],
    );
    assert!(
        out.contains("set -gx PATH '/usr/bin' '/bin'\n"),
        "a colon-joined string would break fish's own command lookup:\n{out}"
    );
    assert_parses(&out, "fish", "-n");
}

#[test]
fn the_gated_directory_leads_the_path_only_while_an_identity_is_active() {
    let s = Sandbox::new();
    let gated = [("VJENV_GATED_DIR", "/gated/bin"), ("PATH", "/usr/bin")];

    let loose = s.ok_with_env(&s.home.join("elsewhere"), &["env", "posix"], &gated);
    assert!(
        !loose.contains("/gated/bin"),
        "no identity means no gate:\n{loose}"
    );

    s.ok(&s.project(), &["assign", "--identity", "goxore"]);
    let gated_out = s.ok_with_env(&s.project(), &["env", "posix"], &gated);
    assert!(
        gated_out.contains("export PATH='/gated/bin:/usr/bin'\n"),
        "the gate must lead:\n{gated_out}"
    );
}

#[test]
fn a_gated_directory_inherited_twice_is_collapsed_to_one() {
    let s = Sandbox::new();
    s.ok(&s.project(), &["assign", "--identity", "goxore"]);
    let out = s.ok_with_env(
        &s.project(),
        &["env", "posix"],
        &[
            ("VJENV_GATED_DIR", "/gated/bin"),
            ("PATH", "/gated/bin:/usr/bin:/gated/bin"),
        ],
    );
    assert!(
        out.contains("export PATH='/gated/bin:/usr/bin'\n"),
        "a stale duplicate must not survive to shadow the current gate:\n{out}"
    );
}

#[test]
fn an_environment_that_already_agrees_produces_no_instructions() {
    let s = Sandbox::new();
    let p = s.project();
    s.ok(&p, &["assign", "--identity", "goxore"]);

    let first = s.ok_with_env(&p, &["env", "posix"], &[("PATH", "/usr/bin")]);
    let mut settled: Vec<(String, String)> = vec![("PATH".into(), "/usr/bin".into())];
    for line in first.lines() {
        let Some(rest) = line.strip_prefix("export ") else {
            continue;
        };
        let (name, value) = rest.split_once('=').expect("an export names a variable");
        let value = value.trim_matches('\'').to_string();
        settled.retain(|(k, _)| k != name);
        settled.push((name.to_string(), value));
    }

    let borrowed: Vec<(&str, &str)> = settled
        .iter()
        .map(|(k, v)| (k.as_str(), v.as_str()))
        .collect();
    let second = s.ok_with_env(&p, &["env", "posix"], &borrowed);
    assert_eq!(
        second, "",
        "a settled environment must cost nothing to re-apply:\n{second}"
    );
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
    assert!(
        !after.contains("__vjenv_env_pending"),
        "deny must be remembered:\n{after}"
    );
}

#[test]
fn an_allowed_project_is_never_offered_again_when_its_flake_changes() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("flake.nix"), "{}").unwrap();
    s.ok(&p, &["allow"]);

    std::fs::write(p.join("flake.nix"), "{ changed = true; }").unwrap();
    let after = s.ok(&p, &["env", "fish"]);
    assert!(
        !after.contains("__vjenv_env_pending"),
        "editing your own flake is not a reason to ask again:\n{after}"
    );

    let listed = s.ok(&p, &["status"]);
    assert!(listed.contains("[allow]"), "{listed}");
}

#[test]
fn a_posix_shell_loads_the_dev_environment_but_is_never_asked() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("flake.nix"), "{}").unwrap();

    let unasked = s.ok(&p, &["env", "posix"]);
    assert!(
        !unasked.contains("__vjenv_env_pending"),
        "a posix shell has no way to answer a prompt:\n{unasked}"
    );

    s.ok(&p, &["allow"]);
    let out = s.run(&p, &["env", "posix"]);
    assert!(
        String::from_utf8_lossy(&out.stderr).contains("VJENV_FLAKE_LOADER is not set"),
        "a posix shell must reach the loader, not skip it"
    );
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
    let still_there =
        std::fs::read_to_string(s.home.join(".local/state/vjenv/projects.toml")).unwrap();
    assert!(still_there.contains("temporary"));

    s.ok(&s.home, &["gc"]);
    let after = std::fs::read_to_string(s.home.join(".local/state/vjenv/projects.toml")).unwrap();
    assert!(!after.contains("temporary"), "{after}");
    assert!(after.contains("secretspec"), "{after}");
}

#[test]
fn gc_keeps_only_caches_whose_root_is_alive() {
    let s = Sandbox::new();
    let devshell = s.home.join(".local/state/vjenv/devshell");
    std::fs::create_dir_all(&devshell).unwrap();
    std::fs::write(devshell.join("live.rc"), "").unwrap();
    std::os::unix::fs::symlink(&s.home, devshell.join("live.gcroot")).unwrap();
    std::fs::write(devshell.join("collected.rc"), "").unwrap();
    std::fs::write(devshell.join("legacy.env"), "").unwrap();

    s.ok(&s.home, &["gc"]);
    assert!(devshell.join("live.rc").exists());
    assert!(devshell.join("live.gcroot").exists());
    assert!(!devshell.join("collected.rc").exists());
    assert!(!devshell.join("legacy.env").exists());
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
    let out = s.ok(&dir, &["status"]);
    assert!(
        out.contains(&format!("root     : {} (marker)", dir.display())),
        "{out}"
    );
}

#[test]
fn completions_are_produced_for_fish() {
    let s = Sandbox::new();
    let out = s.ok(&s.home, &["completions", "fish"]);
    assert!(out.contains("vjenv"), "{out}");
    assert!(out.contains("assign"), "{out}");
}

struct Session<'a> {
    sandbox: &'a Sandbox,
    env: Vec<(String, String)>,
}

impl<'a> Session<'a> {
    fn new(sandbox: &'a Sandbox, extra: &[(&str, &str)]) -> Self {
        let mut env = vec![("PATH".to_string(), sandbox.path())];
        env.extend(extra.iter().map(|(k, v)| (k.to_string(), v.to_string())));
        Self { sandbox, env }
    }

    fn enter(&mut self, dir: &Path) -> String {
        let borrowed: Vec<(&str, &str)> = self
            .env
            .iter()
            .map(|(k, v)| (k.as_str(), v.as_str()))
            .collect();
        let out = self.sandbox.with_env(dir, &["env", "posix"], &borrowed);
        assert!(
            out.status.success(),
            "vjenv env failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );

        let applied = Command::new("sh")
            .args(["-c", "eval \"$1\" && env -0", "_"])
            .arg(String::from_utf8(out.stdout).unwrap())
            .env_clear()
            .envs(self.env.iter().cloned())
            .output()
            .unwrap();
        assert!(applied.status.success(), "the emitted code must apply");
        self.env = applied
            .stdout
            .split(|b| *b == 0)
            .filter_map(|kv| {
                let (k, v) = std::str::from_utf8(kv).ok()?.split_once('=')?;
                (!["PWD", "OLDPWD", "SHLVL", "_"].contains(&k)).then(|| (k.into(), v.into()))
            })
            .collect();
        String::from_utf8(out.stderr).unwrap()
    }

    fn get(&self, name: &str) -> Option<&str> {
        self.env
            .iter()
            .find(|(k, _)| k == name)
            .map(|(_, v)| v.as_str())
    }

    fn search_path(&self) -> Vec<&str> {
        self.get("PATH").unwrap_or_default().split(':').collect()
    }
}

fn calls(s: &Sandbox, log: &str) -> usize {
    std::fs::read_to_string(s.home.join(log))
        .map(|t| t.lines().count())
        .unwrap_or(0)
}

fn fake_devenv(s: &Sandbox) {
    s.fake(
        "devenv",
        r#"echo "$PWD" >> "$HOME/devenv-calls"
cat <<EOF
export GREETING=hello
export PATH='/dev/bin:$PATH:/dev/tail/bin'
echo entered-shell
EOF
"#,
    );
}

fn fake_nix(s: &Sandbox) {
    s.fake(
        "nix",
        r#"echo "$*" >> "$HOME/nix-calls"
while [ $# -gt 0 ]; do
  [ "$1" = --profile ] && profile=$2
  shift
done
mkdir -p "$HOME/store/env"
ln -sfn "$HOME/store/env" "$profile"
cat <<'EOF'
export FLAKE_VAR=1
PATH=/flake/bin:$PATH
echo flake-hook
EOF
"#,
    );
    s.fake(
        "nix-store",
        r#"while [ $# -gt 0 ]; do
  case $1 in
    --add-root) root=$2; shift ;;
    --realise) target=$2; shift ;;
  esac
  shift
done
ln -sfn "$target" "$root"
"#,
    );
}

#[test]
fn a_devenv_project_is_entered_through_devenv_every_time() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("devenv.nix"), "{}").unwrap();
    fake_devenv(&s);
    s.ok(&p, &["allow"]);
    let mut sh = Session::new(&s, &[]);

    let first = sh.enter(&p);
    assert!(
        first.contains("entered-shell"),
        "enterShell output must reach the terminal:\n{first}"
    );
    assert_eq!(sh.get("GREETING"), Some("hello"));
    assert_eq!(sh.search_path()[..2], ["/dev/bin", "/dev/tail/bin"]);

    let settled = sh.enter(&p.join("src"));
    assert_eq!(settled, "", "staying inside must not enter again");
    assert_eq!(calls(&s, "devenv-calls"), 1);

    sh.enter(&s.home.join("elsewhere"));
    assert_eq!(sh.get("GREETING"), None, "leaving must restore the shell");
    assert!(!sh.search_path().contains(&"/dev/bin"));

    let again = sh.enter(&p);
    assert!(again.contains("entered-shell"), "{again}");
    assert_eq!(calls(&s, "devenv-calls"), 2);
}

#[test]
fn the_shell_search_path_is_never_frozen_into_a_dev_environment() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("devenv.nix"), "{}").unwrap();
    fake_devenv(&s);
    s.ok(&p, &["allow"]);
    s.ok(&s.home.join("nixconf"), &["assign", "--identity", "goxore"]);
    let mut sh = Session::new(&s, &[("VJENV_GATED_DIR", "/gated/bin")]);

    sh.enter(&s.home.join("nixconf"));
    assert_eq!(sh.search_path()[0], "/gated/bin");

    sh.enter(&p);
    let path = sh.search_path();
    assert!(
        !path.contains(&"/gated/bin"),
        "an unassigned project must not inherit the gate through devenv:\n{path:?}"
    );
    let own = s.home.join("bin");
    assert_eq!(
        path.iter().filter(|e| Path::new(e) == own).count(),
        1,
        "the shell's own entries must appear once:\n{path:?}"
    );
}

#[test]
fn a_devenv_project_that_also_has_a_flake_is_entered_through_devenv() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("devenv.nix"), "{}").unwrap();
    std::fs::write(p.join("flake.nix"), "{}").unwrap();
    fake_devenv(&s);
    fake_nix(&s);
    s.ok(&p, &["allow"]);

    Session::new(&s, &[]).enter(&p);
    assert_eq!(calls(&s, "devenv-calls"), 1);
    assert_eq!(calls(&s, "nix-calls"), 0);
}

#[test]
fn a_failing_devenv_is_not_retried_until_something_changes() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("devenv.nix"), "{}").unwrap();
    s.fake(
        "devenv",
        "echo x >> \"$HOME/devenv-calls\"\necho broken >&2\nexit 1\n",
    );
    s.ok(&p, &["allow"]);
    let mut sh = Session::new(&s, &[]);

    let first = sh.enter(&p);
    assert!(first.contains("broken"), "{first}");
    sh.enter(&p);
    assert_eq!(calls(&s, "devenv-calls"), 1);

    std::fs::write(p.join("devenv.nix"), "{ fixed = true; }").unwrap();
    sh.enter(&p);
    assert_eq!(calls(&s, "devenv-calls"), 2);
}

#[test]
fn a_flake_is_evaluated_once_but_its_hook_runs_on_every_entry() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("flake.nix"), "{}").unwrap();
    fake_nix(&s);
    s.ok(&p, &["allow"]);
    let mut sh = Session::new(&s, &[("VJENV_FLAKE_LOADER", "/loader.nix")]);

    let first = sh.enter(&p);
    assert!(first.contains("evaluating the dev environment"), "{first}");
    assert!(first.contains("flake-hook"), "{first}");
    assert_eq!(sh.get("FLAKE_VAR"), Some("1"));
    assert_eq!(sh.search_path()[0], "/flake/bin");

    sh.enter(&s.home.join("elsewhere"));
    assert_eq!(sh.get("FLAKE_VAR"), None);
    let again = sh.enter(&p);
    assert!(again.contains("flake-hook"), "{again}");
    assert!(!again.contains("evaluating"), "{again}");
    assert_eq!(calls(&s, "nix-calls"), 1);

    std::fs::write(p.join("flake.lock"), "{}").unwrap();
    let changed = sh.enter(&p);
    assert!(changed.contains("changed"), "{changed}");
    assert_eq!(calls(&s, "nix-calls"), 2);

    let collected = s.ok(&s.home, &["gc", "--dry-run"]);
    assert!(collected.contains("nothing to collect"), "{collected}");
}

#[test]
fn exec_runs_a_command_inside_the_dev_environment() {
    let s = Sandbox::new();
    let p = s.project();
    std::fs::write(p.join("devenv.nix"), "{}").unwrap();
    fake_devenv(&s);
    s.ok(&p, &["allow"]);
    let out = s.ok(&p, &["exec", "sh", "-c", "printf %s \"$GREETING\""]);
    assert_eq!(out, "hello");
}
