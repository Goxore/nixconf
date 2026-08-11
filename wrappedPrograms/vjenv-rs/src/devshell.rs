use crate::emit::EnvOp;
use crate::paths::{atomic_write, Dirs};
use anyhow::{bail, Context, Result};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, SystemTime};

const FAILURE_TTL: Duration = Duration::from_secs(60 * 60);

pub const SKIP: &[&str] = &[
    "PATH", "PWD", "OLDPWD", "SHLVL", "SHELL", "HOME", "USER", "LOGNAME",
    "TERM", "TERMINFO", "COLORTERM", "DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY",
    "DBUS_SESSION_BUS_ADDRESS", "IFS", "PS1", "PS2", "PS3", "PS4",
    "BASH", "BASHOPTS", "BASHPID", "BASH_EXECUTION_STRING", "BASH_VERSION",
    "BASH_VERSINFO", "BASH_ARGC", "BASH_ARGV", "BASH_LINENO", "BASH_SOURCE",
    "BASH_CMDS", "BASH_ALIASES", "EUID", "UID", "PPID", "HOSTNAME", "HOSTTYPE",
    "MACHTYPE", "OSTYPE", "SHELLOPTS", "OPTERR", "OPTIND", "RANDOM", "SECONDS",
    "LINENO", "GROUPS", "DIRSTACK", "FUNCNAME", "COLUMNS", "LINES", "_",
    "TMP", "TMPDIR", "TEMP", "TEMPDIR", "TZ",
    "NIX_BUILD_TOP", "NIX_BUILD_CORES", "NIX_LOG_FD", "NIX_ENFORCE_PURITY",
    "out", "outputs", "phases", "builder", "system", "stdenv", "shell", "src",
    "name", "pname", "version", "shellHook",
    "XDG_RUNTIME_DIR", "XDG_CONFIG_HOME", "XDG_STATE_HOME", "XDG_DATA_HOME",
    "XDG_CACHE_HOME",
    "VJENV_IDENTITY", "VJENV_ROOT", "VJENV_PINNED", "VJENV_OVERRIDE",
    "VJENV_ENV_ROOT", "VJENV_TEMPLATE", "VJENV_SYSTEM",
    "GIT_CONFIG_COUNT", "GIT_CONFIG_KEY_0", "GIT_CONFIG_VALUE_0",
    "GIT_CONFIG_KEY_1", "GIT_CONFIG_VALUE_1", "GIT_CONFIG_KEY_2",
    "GIT_CONFIG_VALUE_2", "GIT_SSH_COMMAND", "GH_CONFIG_DIR", "JJ_CONFIG",
];

const STAMPED: &[&str] = &[
    "flake.nix",
    "flake.lock",
    "flake/flake.nix",
    "flake/flake.lock",
    "devenv.nix",
    "devenv.lock",
    "devenv.yaml",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Flake,
    Devenv,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Project {
    pub dir: PathBuf,
    pub kind: Kind,
    pub base: PathBuf,
}

pub fn find(start: &Path, home: &Path) -> Option<Project> {
    for dir in start.ancestors() {
        if let Some(p) = at(dir) {
            return Some(p);
        }
        if dir == home {
            break;
        }
    }
    None
}

fn at(dir: &Path) -> Option<Project> {
    if dir.join("flake.nix").is_file() {
        Some(Project { dir: dir.into(), kind: Kind::Flake, base: dir.into() })
    } else if dir.join("devenv.nix").is_file() {
        Some(Project { dir: dir.into(), kind: Kind::Devenv, base: dir.into() })
    } else if dir.join("flake/flake.nix").is_file() {
        Some(Project { dir: dir.into(), kind: Kind::Flake, base: dir.join("flake") })
    } else {
        None
    }
}

impl Project {
    pub fn installable(&self, system: &str, shell: Option<&str>) -> String {
        match (self.kind, shell) {
            (Kind::Flake, Some(name)) => {
                format!("{}#devShells.{system}.{name}", self.base.display())
            }
            _ => self.base.display().to_string(),
        }
    }

    pub fn shells(&self, system: &str) -> Result<Vec<String>> {
        if self.kind != Kind::Flake {
            return Ok(Vec::new());
        }
        let out = Command::new("nix")
            .args(["eval", "--impure", "--raw"])
            .arg(format!("{}#devShells.{system}", self.base.display()))
            .args(["--apply", r#"s: builtins.concatStringsSep "\n" (builtins.attrNames s)"#])
            .output()
            .context("cannot run nix")?;
        if !out.status.success() {
            return Ok(Vec::new());
        }
        Ok(String::from_utf8_lossy(&out.stdout)
            .lines()
            .filter(|l| !l.is_empty())
            .map(str::to_string)
            .collect())
    }

    fn cache_key(&self, installable: &str) -> String {
        let mut h = Sha256::new();
        h.update(b"v1\n");
        h.update(installable.as_bytes());
        h.update(b"\n");
        for name in STAMPED {
            let p = self.dir.join(name);
            if let Ok(m) = p.metadata() {
                let secs = m
                    .modified()
                    .ok()
                    .and_then(|t| t.duration_since(SystemTime::UNIX_EPOCH).ok())
                    .map_or(0, |d| d.as_secs());
                h.update(format!("{name}:{secs}\n").as_bytes());
            }
        }
        hex(&h.finalize())
    }
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().fold(String::new(), |mut s, b| {
        use std::fmt::Write as _;
        let _ = write!(s, "{b:02x}");
        s
    })
}

struct Scratch(PathBuf);

impl Scratch {
    fn new(dir: &Path) -> Result<Self> {
        std::fs::create_dir_all(dir)?;
        Ok(Self(dir.join(format!(".rc.{}", std::process::id()))))
    }
    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for Scratch {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.0);
    }
}

#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct DevEnv {
    pub vars: Vec<(String, String)>,
    pub path: Vec<String>,
}

impl DevEnv {
    pub fn ops(&self) -> Vec<EnvOp> {
        self.vars
            .iter()
            .map(|(k, v)| EnvOp::set(k.clone(), v.clone()))
            .collect()
    }
}

pub fn parse_dump(bytes: &[u8]) -> Vec<(String, String)> {
    bytes
        .split(|b| *b == 0)
        .filter(|c| !c.is_empty())
        .filter_map(|chunk| {
            let text = String::from_utf8_lossy(chunk);
            let (k, v) = text.split_once('=')?;
            is_identifier(k).then(|| (k.to_string(), v.to_string()))
        })
        .collect()
}

fn is_identifier(s: &str) -> bool {
    let mut chars = s.chars();
    matches!(chars.next(), Some(c) if c.is_ascii_alphabetic() || c == '_')
        && chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

pub fn select(dump: &[(String, String)]) -> DevEnv {
    let mut out = DevEnv::default();
    for (k, v) in dump {
        if k == "PATH" {
            out.path = v.split(':').filter(|p| !p.is_empty()).map(str::to_string).collect();
        } else if !SKIP.contains(&k.as_str()) {
            out.vars.push((k.clone(), v.clone()));
        }
    }
    out
}

const DIFF: &str = r#"
declare -A before
while IFS= read -r -d "" kv; do before[${kv%%=*}]=${kv#*=}; done < <(env -0)
caller_path="$PATH"
. "$1" >&2
[ -n "$caller_path" ] && PATH="${PATH%":$caller_path"}"
export PATH
while IFS= read -r -d "" kv; do
  k=${kv%%=*}
  v=${kv#*=}
  if [ "${before[$k]+set}" != set ] || [ "${before[$k]}" != "$v" ]; then
    printf "%s=%s\0" "$k" "$v"
  fi
done < <(env -0)
"#;

pub struct Loader<'a> {
    pub dirs: &'a Dirs,
    pub system: &'a str,
}

impl Loader<'_> {
    fn paths(&self, key: &str) -> (PathBuf, PathBuf, PathBuf) {
        (
            self.dirs.devshell().join(format!("{key}.env")),
            self.dirs.devshell().join(format!("{key}.fail")),
            self.dirs.profiles().join(key),
        )
    }

    fn is_live(env: &DevEnv, profile: &Path) -> bool {
        if profile.symlink_metadata().is_ok() {
            return profile.canonicalize().is_ok_and(|p| p.exists());
        }
        let mut store_paths = env
            .path
            .iter()
            .filter(|p| p.starts_with("/nix/store/"))
            .peekable();
        store_paths.peek().is_none() || store_paths.all(|p| Path::new(p).exists())
    }

    fn failure_is_fresh(marker: &Path) -> bool {
        marker
            .metadata()
            .and_then(|m| m.modified())
            .and_then(|t| SystemTime::now().duration_since(t).map_err(std::io::Error::other))
            .is_ok_and(|age| age < FAILURE_TTL)
    }

    pub fn forget(&self, project: &Project, shell: Option<&str>) -> Result<()> {
        let key = project.cache_key(&project.installable(self.system, shell));
        let (cache, fail, profile) = self.paths(&key);
        for p in [&cache, &fail] {
            if p.exists() {
                std::fs::remove_file(p)?;
            }
        }
        for p in [
            profile.clone(),
            with_suffix(&profile, "-1-link"),
            with_suffix(&profile, ".gcroot"),
        ] {
            if p.symlink_metadata().is_ok() {
                std::fs::remove_file(&p)?;
            }
        }
        Ok(())
    }

    pub fn load(&self, project: &Project, shell: Option<&str>) -> Result<DevEnv> {
        let installable = project.installable(self.system, shell);
        let key = project.cache_key(&installable);
        let (cache, fail, profile) = self.paths(&key);

        if cache.is_file() {
            let env = select(&parse_dump(&std::fs::read(&cache)?));
            if Self::is_live(&env, &profile) {
                return Ok(env);
            }
        }
        if Self::failure_is_fresh(&fail) {
            bail!(
                "the dev environment in {} failed to evaluate recently — \
                 run `vjenv reload` to retry now",
                project.dir.display()
            );
        }

        std::fs::create_dir_all(self.dirs.devshell())?;
        std::fs::create_dir_all(self.dirs.profiles())?;
        eprintln!("vjenv: evaluating the dev environment in {} ...", project.dir.display());

        match self.evaluate(project, &installable, &profile) {
            Ok(dump) => {
                let _ = std::fs::remove_file(&fail);
                atomic_write(&cache, &dump)?;
                Ok(select(&parse_dump(&dump)))
            }
            Err(e) => {
                let _ = atomic_write(&fail, b"");
                Err(e)
            }
        }
    }

    fn evaluate(&self, project: &Project, installable: &str, profile: &Path) -> Result<Vec<u8>> {
        let rc = Scratch::new(&self.dirs.devshell())?;

        let produced = match project.kind {
            Kind::Devenv => Command::new("devenv")
                .current_dir(&project.dir)
                .env("NIXPKGS_ALLOW_UNFREE", "1")
                .arg("direnv-export")
                .stdout(std::fs::File::create(rc.path())?)
                .status()
                .context("cannot run devenv — is it installed?")?,
            Kind::Flake => Command::new("nix")
                .env("NIXPKGS_ALLOW_UNFREE", "1")
                .args(["print-dev-env", "--impure", "--profile"])
                .arg(profile)
                .arg(installable)
                .stdout(std::fs::File::create(rc.path())?)
                .status()
                .context("cannot run nix")?,
        };
        if !produced.success() {
            bail!("evaluating {installable} failed");
        }

        if project.kind == Kind::Flake {
            self.register_root(profile);
        }

        let out = Command::new("bash")
            .args(["--norc", "--noprofile", "-c", DIFF, "_"])
            .arg(rc.path())
            .output()
            .context("cannot run bash")?;
        if !out.status.success() {
            bail!("sourcing the dev environment of {installable} failed");
        }
        Ok(out.stdout)
    }

    fn register_root(&self, profile: &Path) {
        let Ok(target) = profile.canonicalize() else {
            return;
        };
        let root = with_suffix(profile, ".gcroot");
        let _ = std::fs::remove_file(&root);

        let status = Command::new("nix-store")
            .arg("--add-root")
            .arg(&root)
            .arg("--indirect")
            .arg("--realise")
            .arg(&target)
            .stdout(std::process::Stdio::null())
            .status();
        if !matches!(status, Ok(s) if s.success()) {
            eprintln!(
                "vjenv: warning — could not register a GC root for {}; \
                 nix-collect-garbage may delete this environment",
                profile.display()
            );
        }
    }
}

fn with_suffix(path: &Path, suffix: &str) -> PathBuf {
    let mut s = path.as_os_str().to_os_string();
    s.push(suffix);
    PathBuf::from(s)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dump(pairs: &[(&str, &str)]) -> Vec<u8> {
        let mut out = Vec::new();
        for (k, v) in pairs {
            out.extend_from_slice(format!("{k}={v}").as_bytes());
            out.push(0);
        }
        out
    }

    #[test]
    fn parses_a_nul_separated_dump() {
        let raw = dump(&[("FOO", "bar"), ("EMPTY", ""), ("WITH_EQ", "a=b")]);
        assert_eq!(
            parse_dump(&raw),
            vec![
                ("FOO".into(), "bar".into()),
                ("EMPTY".into(), "".into()),
                ("WITH_EQ".into(), "a=b".into()),
            ]
        );
    }

    #[test]
    fn values_may_contain_newlines_and_quotes() {
        let raw = dump(&[("SCRIPT", "line1\nline2 'q' \"d\"")]);
        assert_eq!(parse_dump(&raw)[0].1, "line1\nline2 'q' \"d\"");
    }

    #[test]
    fn non_identifier_names_are_dropped() {
        let raw = dump(&[("BASH_FUNC_x%%", "() { :; }"), ("OK", "1"), ("2BAD", "x")]);
        let got = parse_dump(&raw);
        assert_eq!(got, vec![("OK".into(), "1".into())]);
    }

    #[test]
    fn path_is_split_out_and_noise_is_skipped() {
        let raw = parse_dump(&dump(&[
            ("PATH", "/nix/store/a/bin:/nix/store/b/bin"),
            ("CARGO_HOME", "/x/cargo"),
            ("SHLVL", "3"),
            ("HOME", "/home/yurii"),
            ("shellHook", "echo hi"),
            ("JJ_CONFIG", "/should/not/leak"),
        ]));
        let env = select(&raw);
        assert_eq!(env.path, vec!["/nix/store/a/bin", "/nix/store/b/bin"]);
        assert_eq!(env.vars, vec![("CARGO_HOME".into(), "/x/cargo".into())]);
    }

    #[test]
    fn an_empty_path_yields_no_entries() {
        let env = select(&parse_dump(&dump(&[("PATH", "")])));
        assert!(env.path.is_empty());
    }

    #[test]
    fn vjenv_and_git_variables_are_never_captured() {
        let raw = parse_dump(&dump(&[
            ("VJENV_IDENTITY", "goxore"),
            ("VJENV_ROOT", "/h/x"),
            ("GIT_CONFIG_COUNT", "3"),
            ("GIT_SSH_COMMAND", "ssh -i /k"),
            ("GH_CONFIG_DIR", "/d"),
            ("KEEP", "yes"),
        ]));
        let env = select(&raw);
        assert_eq!(env.vars, vec![("KEEP".into(), "yes".into())]);
    }

    #[test]
    fn finds_a_flake_walking_upward() {
        let tmp = tempfile::tempdir().unwrap();
        let home = tmp.path();
        let deep = home.join("proj/src/deep");
        std::fs::create_dir_all(&deep).unwrap();
        std::fs::write(home.join("proj/flake.nix"), "{}").unwrap();

        let p = find(&deep, home).unwrap();
        assert_eq!(p.kind, Kind::Flake);
        assert_eq!(p.dir, home.join("proj"));
        assert_eq!(p.base, home.join("proj"));
    }

    #[test]
    fn finds_a_flake_in_a_flake_subdirectory() {
        let tmp = tempfile::tempdir().unwrap();
        let home = tmp.path();
        std::fs::create_dir_all(home.join("proj/flake")).unwrap();
        std::fs::write(home.join("proj/flake/flake.nix"), "{}").unwrap();

        let p = find(&home.join("proj"), home).unwrap();
        assert_eq!(p.dir, home.join("proj"));
        assert_eq!(p.base, home.join("proj/flake"));
    }

    #[test]
    fn a_root_level_flake_takes_precedence_over_the_subdirectory() {
        let tmp = tempfile::tempdir().unwrap();
        let home = tmp.path();
        std::fs::create_dir_all(home.join("proj/flake")).unwrap();
        std::fs::write(home.join("proj/flake.nix"), "{}").unwrap();
        std::fs::write(home.join("proj/flake/flake.nix"), "{}").unwrap();

        assert_eq!(find(&home.join("proj"), home).unwrap().base, home.join("proj"));
    }

    #[test]
    fn the_search_stops_at_home() {
        let tmp = tempfile::tempdir().unwrap();
        let home = tmp.path().join("home");
        std::fs::create_dir_all(home.join("proj")).unwrap();
        std::fs::write(tmp.path().join("flake.nix"), "{}").unwrap();

        assert_eq!(find(&home.join("proj"), &home), None);
    }

    #[test]
    fn installable_names_the_chosen_devshell() {
        let p = Project {
            dir: "/h/proj".into(),
            kind: Kind::Flake,
            base: "/h/proj".into(),
        };
        assert_eq!(p.installable("x86_64-linux", None), "/h/proj");
        assert_eq!(
            p.installable("x86_64-linux", Some("ci")),
            "/h/proj#devShells.x86_64-linux.ci"
        );
    }

    #[test]
    fn devenv_ignores_a_devshell_name() {
        let p = Project {
            dir: "/h/proj".into(),
            kind: Kind::Devenv,
            base: "/h/proj".into(),
        };
        assert_eq!(p.installable("x86_64-linux", Some("ci")), "/h/proj");
    }

    #[test]
    fn the_cache_key_tracks_the_installable_and_the_lockfile() {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path().to_path_buf();
        std::fs::write(dir.join("flake.nix"), "{}").unwrap();
        std::fs::write(dir.join("flake.lock"), "{}").unwrap();
        let p = Project { dir: dir.clone(), kind: Kind::Flake, base: dir.clone() };

        let a = p.cache_key("x");
        assert_eq!(a, p.cache_key("x"), "key must be stable");
        assert_ne!(a, p.cache_key("y"), "installable must matter");

        let later = SystemTime::now() + Duration::from_secs(120);
        std::fs::File::open(dir.join("flake.lock"))
            .unwrap()
            .set_modified(later)
            .unwrap();
        assert_ne!(a, p.cache_key("x"), "a changed lockfile must invalidate");
    }

    #[test]
    fn a_dangling_profile_invalidates_the_cache() {
        let tmp = tempfile::tempdir().unwrap();
        let profile = tmp.path().join("k");
        let env = DevEnv::default();

        std::os::unix::fs::symlink(tmp.path().join("gone"), &profile).unwrap();
        assert!(!Loader::is_live(&env, &profile), "dangling profile");

        std::fs::write(tmp.path().join("gone"), "").unwrap();
        assert!(Loader::is_live(&env, &profile), "resolvable profile");
    }

    #[test]
    fn without_a_profile_every_store_path_must_still_exist() {
        let tmp = tempfile::tempdir().unwrap();
        let absent = tmp.path().join("no-profile");

        let nothing_to_check = DevEnv {
            path: vec!["/usr/bin".into()],
            ..Default::default()
        };
        assert!(Loader::is_live(&nothing_to_check, &absent));

        let collected = DevEnv {
            path: vec!["/nix/store/0000000000000000000000000000000-gone/bin".into()],
            ..Default::default()
        };
        assert!(!Loader::is_live(&collected, &absent));

        let partly_collected = DevEnv {
            path: vec![
                "/nix/store".into(),
                "/nix/store/0000000000000000000000000000000-gone/bin".into(),
            ],
            ..Default::default()
        };
        assert!(!Loader::is_live(&partly_collected, &absent));
    }

    #[test]
    fn a_stale_failure_marker_stops_blocking() {
        let tmp = tempfile::tempdir().unwrap();
        let marker = tmp.path().join("k.fail");
        std::fs::write(&marker, "").unwrap();
        assert!(Loader::failure_is_fresh(&marker));

        let old = SystemTime::now() - FAILURE_TTL - Duration::from_secs(60);
        std::fs::File::options()
            .write(true)
            .open(&marker)
            .unwrap()
            .set_modified(old)
            .unwrap();
        assert!(!Loader::failure_is_fresh(&marker));
        assert!(!Loader::failure_is_fresh(&tmp.path().join("absent.fail")));
    }
}
