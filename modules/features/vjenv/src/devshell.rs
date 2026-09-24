use crate::identity;
use crate::paths::{Dirs, atomic_write};
use crate::project::{Kind, Project};
use crate::searchpath;
use crate::session::{self, Env};
use anyhow::{Context, Result, bail};
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

const NOISE: &[&str] = &[
    "PATH",
    "PWD",
    "OLDPWD",
    "SHLVL",
    "_",
    "HOME",
    "USER",
    "LOGNAME",
    "SHELL",
    "TERM",
    "TZ",
    "TMP",
    "TMPDIR",
    "TEMP",
    "TEMPDIR",
    "NIX_BUILD_TOP",
    "NIX_BUILD_CORES",
    "NIX_LOG_FD",
    "NIX_ENFORCE_PURITY",
    "NIX_REMOTE",
    "out",
    "outputs",
    "phases",
    "builder",
    "system",
    "stdenv",
    "shell",
    "src",
    "name",
    "pname",
    "version",
    "shellHook",
    "XDG_RUNTIME_DIR",
    "XDG_CONFIG_HOME",
    "XDG_STATE_HOME",
    "XDG_DATA_HOME",
    "XDG_CACHE_HOME",
    "VJENV_OVERRIDE",
    "VJENV_SYSTEM",
    "VJENV_FLAKE_LOADER",
    searchpath::GATED_DIR_VAR,
];

const DIFF: &str = r#"
declare -A before
while IFS= read -r -d "" kv; do before[${kv%%=*}]=${kv#*=}; done < <(env -0)
. "$1" >&2
if [[ ${NIX_BUILD_TOP-} == */nix-shell.* && -d $NIX_BUILD_TOP ]]; then
  rm -rf "$NIX_BUILD_TOP"
fi
export PATH
while IFS= read -r -d "" kv; do
  k=${kv%%=*}
  v=${kv#*=}
  if [ "${before[$k]+set}" != set ] || [ "${before[$k]}" != "$v" ]; then
    printf "%s=%s\0" "$k" "$v"
  fi
done < <(env -0)
"#;

#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct DevEnv {
    pub vars: Vec<(String, String)>,
    pub path: Vec<String>,
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

fn captured(name: &str) -> bool {
    !NOISE.contains(&name)
        && !identity::MANAGED.contains(&name)
        && !session::MARKERS.contains(&name)
}

pub fn select(dump: &[(String, String)], base_path: &str) -> DevEnv {
    let inherited: Vec<&str> = searchpath::split(base_path).collect();
    let mut out = DevEnv::default();
    for (k, v) in dump {
        if k == "PATH" {
            for entry in searchpath::split(v) {
                if !inherited.contains(&entry) && !out.path.iter().any(|p| p == entry) {
                    out.path.push(entry.to_string());
                }
            }
        } else if captured(k) {
            out.vars.push((k.clone(), v.clone()));
        }
    }
    out
}

struct Scratch(PathBuf);

impl Scratch {
    fn new(parent: &Path) -> Result<Self> {
        let dir = parent.join(format!(".scratch.{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir)
            .with_context(|| format!("cannot create {}", dir.display()))?;
        Ok(Self(dir))
    }

    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for Scratch {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn is_live(root: &Path) -> bool {
    root.canonicalize().is_ok()
}

pub struct Loader<'a> {
    pub dirs: &'a Dirs,
    pub system: &'a str,
    pub flake_loader: Option<&'a Path>,
}

impl Loader<'_> {
    pub fn flake_args(&self, project: &Project) -> Result<Vec<OsString>> {
        let loader = self.flake_loader.context("VJENV_FLAKE_LOADER is not set")?;
        Ok(vec![
            "--file".into(),
            loader.into(),
            "--argstr".into(),
            "dir".into(),
            project.base.clone().into(),
            "--argstr".into(),
            "system".into(),
            self.system.into(),
        ])
    }

    pub fn shells(&self, project: &Project) -> Result<Vec<String>> {
        if project.kind != Kind::Flake {
            return Ok(Vec::new());
        }
        let out = Command::new("nix")
            .args(["eval", "--impure", "--raw"])
            .args(self.flake_args(project)?)
            .arg(format!("outputs.devShells.{}", self.system))
            .args([
                "--apply",
                r#"s: builtins.concatStringsSep "\n" (builtins.attrNames s)"#,
            ])
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

    fn cached(&self, project: &Project, shell: Option<&str>) -> (PathBuf, PathBuf) {
        let series = project.series(&project.installable(self.system, shell));
        let dir = self.dirs.devshell();
        (
            dir.join(format!("{series}.rc")),
            dir.join(format!("{series}.gcroot")),
        )
    }

    pub fn load(&self, project: &Project, shell: Option<&str>, base: &Env) -> Result<DevEnv> {
        let installable = project.installable(self.system, shell);
        let scratch = Scratch::new(&self.dirs.devshell())?;
        let rc = match project.kind {
            Kind::Devenv => self.export_devenv(project, &installable, base)?,
            Kind::Flake => self.flake_rc(project, shell, &installable, base, &scratch)?,
        };

        let script = scratch.path().join("rc");
        std::fs::write(&script, rc)?;
        let out = Command::new("bash")
            .current_dir(&project.dir)
            .env_clear()
            .envs(base)
            .args(["--norc", "--noprofile", "-c", DIFF, "_"])
            .arg(&script)
            .stdin(Stdio::null())
            .stderr(Stdio::inherit())
            .output()
            .context("cannot run bash")?;
        if !out.status.success() {
            bail!("sourcing the dev environment of {installable} failed");
        }

        let base_path = base.get("PATH").map_or("", String::as_str);
        Ok(select(&parse_dump(&out.stdout), base_path))
    }

    fn export_devenv(&self, project: &Project, installable: &str, base: &Env) -> Result<Vec<u8>> {
        let out = Command::new("devenv")
            .current_dir(&project.dir)
            .env_clear()
            .envs(base)
            .env("NIXPKGS_ALLOW_UNFREE", "1")
            .arg("direnv-export")
            .stdin(Stdio::null())
            .stderr(Stdio::inherit())
            .output()
            .context("cannot run devenv — is it installed?")?;
        if !out.status.success() {
            bail!("evaluating {installable} failed");
        }
        Ok(out.stdout)
    }

    fn flake_rc(
        &self,
        project: &Project,
        shell: Option<&str>,
        installable: &str,
        base: &Env,
        scratch: &Scratch,
    ) -> Result<Vec<u8>> {
        let (cache, root) = self.cached(project, shell);
        let header = format!("# {}\n", project.stamp());
        let previous = std::fs::read(&cache).ok();
        if let Some(rc) = &previous
            && rc.starts_with(header.as_bytes())
            && is_live(&root)
        {
            return Ok(rc.clone());
        }

        match previous {
            Some(_) => eprintln!(
                "vjenv: the flake in {} changed, evaluating the dev environment again ...",
                project.dir.display()
            ),
            None => eprintln!(
                "vjenv: evaluating the dev environment in {} ...",
                project.dir.display()
            ),
        }

        let profile = scratch.path().join("profile");
        let out = Command::new("nix")
            .current_dir(&project.dir)
            .env_clear()
            .envs(base)
            .env("NIXPKGS_ALLOW_UNFREE", "1")
            .args(["print-dev-env", "--impure", "--profile"])
            .arg(&profile)
            .args(self.flake_args(project)?)
            .args(["--argstr", "attr", shell.unwrap_or("default"), "shell"])
            .stdin(Stdio::null())
            .stderr(Stdio::inherit())
            .output()
            .context("cannot run nix")?;
        if !out.status.success() {
            bail!("evaluating {installable} failed");
        }

        register_root(&profile, &root);
        let mut rc = header.into_bytes();
        rc.extend(out.stdout);
        atomic_write(&cache, &rc)?;
        Ok(rc)
    }

    pub fn forget(&self, project: &Project, shell: Option<&str>) -> Result<()> {
        let (cache, root) = self.cached(project, shell);
        for p in [cache, root] {
            match std::fs::remove_file(&p) {
                Err(e) if e.kind() != std::io::ErrorKind::NotFound => {
                    return Err(
                        anyhow::Error::from(e).context(format!("cannot remove {}", p.display()))
                    );
                }
                _ => {}
            }
        }
        Ok(())
    }

    pub fn dead(&self) -> Vec<PathBuf> {
        let Ok(entries) = std::fs::read_dir(self.dirs.devshell()) else {
            return Vec::new();
        };
        let mut dead: Vec<PathBuf> = entries
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.is_file() || p.is_symlink())
            .filter(|p| match p.extension().and_then(|x| x.to_str()) {
                Some("rc") => !is_live(&p.with_extension("gcroot")),
                Some("gcroot") => !is_live(p) || !p.with_extension("rc").is_file(),
                _ => true,
            })
            .collect();
        dead.sort();
        dead
    }
}

fn register_root(profile: &Path, root: &Path) {
    let registered = profile.canonicalize().is_ok_and(|target| {
        let _ = std::fs::remove_file(root);
        Command::new("nix-store")
            .arg("--add-root")
            .arg(root)
            .arg("--indirect")
            .arg("--realise")
            .arg(&target)
            .stdout(Stdio::null())
            .status()
            .is_ok_and(|s| s.success())
    });
    if !registered {
        eprintln!(
            "vjenv: warning — could not register a GC root for {}; \
             nix-collect-garbage may delete this environment",
            profile.display()
        );
    }
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
        let raw = dump(&[("SCRIPT", "echo 'hi'\necho \"there\"")]);
        assert_eq!(parse_dump(&raw)[0].1, "echo 'hi'\necho \"there\"");
    }

    #[test]
    fn non_identifier_names_are_dropped() {
        let raw = dump(&[("BASH_FUNC_x%%", "() { :; }"), ("OK", "1")]);
        assert_eq!(parse_dump(&raw), vec![("OK".into(), "1".into())]);
    }

    fn selected(pairs: &[(&str, &str)], base_path: &str) -> DevEnv {
        let owned: Vec<(String, String)> = pairs
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect();
        select(&owned, base_path)
    }

    #[test]
    fn path_is_split_out_and_noise_is_skipped() {
        let env = selected(
            &[
                ("PATH", "/nix/store/a/bin:/nix/store/b/bin"),
                ("CARGO_HOME", "/c"),
                ("SHLVL", "2"),
                ("NIX_BUILD_TOP", "/tmp/nix-shell.x"),
            ],
            "",
        );
        assert_eq!(env.path, vec!["/nix/store/a/bin", "/nix/store/b/bin"]);
        assert_eq!(env.vars, vec![("CARGO_HOME".into(), "/c".into())]);
    }

    #[test]
    fn the_inherited_search_path_is_never_captured() {
        let env = selected(
            &[(
                "PATH",
                "/nix/store/dev/bin:/etc/vjenv/gated/bin:/run/current-system/sw/bin:/p/.devenv/state/bin",
            )],
            "/etc/vjenv/gated/bin:/run/current-system/sw/bin",
        );
        assert_eq!(
            env.path,
            vec!["/nix/store/dev/bin", "/p/.devenv/state/bin"],
            "whatever the shell already had must not be frozen into the project"
        );
    }

    #[test]
    fn a_repeated_entry_is_kept_once() {
        let env = selected(&[("PATH", "/a/bin:/b/bin:/a/bin")], "");
        assert_eq!(env.path, vec!["/a/bin", "/b/bin"]);
    }

    #[test]
    fn vjenv_and_identity_variables_are_never_captured() {
        let env = selected(
            &[
                ("VJENV_IDENTITY", "x"),
                ("VJENV_ENV_ROOT", "/p"),
                ("GIT_SSH_COMMAND", "ssh"),
                ("JJ_CONFIG", "/j"),
                ("VJENV_GATED_DIR", "/g"),
                ("KEPT", "1"),
            ],
            "",
        );
        assert_eq!(env.vars, vec![("KEPT".into(), "1".into())]);
    }

    fn dirs_at(root: &Path) -> Dirs {
        Dirs {
            home: root.to_path_buf(),
            config: root.join("config"),
            state: root.join("state"),
            data: root.join("data"),
            runtime: root.join("run"),
        }
    }

    fn loader(dirs: &Dirs) -> Loader<'_> {
        Loader {
            dirs,
            system: "x86_64-linux",
            flake_loader: Some(Path::new("/loader.nix")),
        }
    }

    #[test]
    fn a_flake_is_loaded_from_its_directory_through_the_loader() {
        let dirs = dirs_at(Path::new("/h"));
        let p = Project {
            dir: "/h/videos".into(),
            kind: Kind::Flake,
            base: "/h/videos/flake".into(),
        };
        assert_eq!(
            loader(&dirs).flake_args(&p).unwrap(),
            [
                "--file",
                "/loader.nix",
                "--argstr",
                "dir",
                "/h/videos/flake",
                "--argstr",
                "system",
                "x86_64-linux",
            ]
        );
    }

    #[test]
    fn a_flake_cannot_load_without_the_loader() {
        let dirs = dirs_at(Path::new("/h"));
        let loader = Loader {
            flake_loader: None,
            ..loader(&dirs)
        };
        let p = Project {
            dir: "/h/proj".into(),
            kind: Kind::Flake,
            base: "/h/proj".into(),
        };
        assert!(loader.flake_args(&p).is_err());
    }

    #[test]
    fn only_a_cache_with_a_live_root_survives() {
        let tmp = tempfile::tempdir().unwrap();
        let dirs = dirs_at(tmp.path());
        let dir = dirs.devshell();
        std::fs::create_dir_all(&dir).unwrap();
        let target = tmp.path().join("store-path");
        std::fs::write(&target, "").unwrap();

        std::fs::write(dir.join("live.rc"), "").unwrap();
        std::os::unix::fs::symlink(&target, dir.join("live.gcroot")).unwrap();
        std::fs::write(dir.join("collected.rc"), "").unwrap();
        std::os::unix::fs::symlink(tmp.path().join("gone"), dir.join("collected.gcroot")).unwrap();
        std::os::unix::fs::symlink(&target, dir.join("orphan.gcroot")).unwrap();
        std::fs::write(dir.join("old.env"), "").unwrap();
        std::fs::create_dir_all(dir.join(".scratch.1")).unwrap();

        assert_eq!(
            loader(&dirs).dead(),
            vec![
                dir.join("collected.gcroot"),
                dir.join("collected.rc"),
                dir.join("old.env"),
                dir.join("orphan.gcroot"),
            ]
        );
    }

    #[test]
    fn forgetting_removes_the_cache_and_its_root() {
        let tmp = tempfile::tempdir().unwrap();
        let dirs = dirs_at(tmp.path());
        let loader = loader(&dirs);
        let p = Project {
            dir: tmp.path().into(),
            kind: Kind::Flake,
            base: tmp.path().into(),
        };
        let (cache, root) = loader.cached(&p, None);
        std::fs::create_dir_all(dirs.devshell()).unwrap();
        std::fs::write(&cache, "").unwrap();
        std::os::unix::fs::symlink(tmp.path(), &root).unwrap();

        loader.forget(&p, None).unwrap();
        assert!(!cache.exists() && !root.is_symlink());
        loader
            .forget(&p, None)
            .expect("forgetting twice is not an error");
    }
}
