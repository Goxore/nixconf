use crate::paths::{expand_tilde, Dirs};
use anyhow::{Context, Result};
use serde::Deserialize;
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Default, Deserialize)]
struct RawConfig {
    #[serde(default)]
    roots: RawRoots,
    #[serde(default)]
    identities: BTreeMap<String, RawIdentity>,
    #[serde(default)]
    accounts: BTreeMap<String, Vec<String>>,
}

#[derive(Debug, Default, Deserialize)]
struct RawRoots {
    #[serde(default)]
    standalone: Vec<String>,
    #[serde(default)]
    containers: Vec<String>,
    #[serde(default)]
    markers: Vec<String>,
}

#[derive(Debug, Default, Deserialize)]
struct RawIdentity {
    name: Option<String>,
    email: Option<String>,
    ssh_key: Option<String>,
}

#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct Roots {
    pub standalone: Vec<PathBuf>,
    pub containers: Vec<PathBuf>,
    pub markers: Vec<String>,
}

#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct Identity {
    pub name: Option<String>,
    pub email: Option<String>,
    pub ssh_key: Option<PathBuf>,
}

#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct Config {
    pub roots: Roots,
    pub identities: BTreeMap<String, Identity>,
    pub accounts: BTreeMap<String, Vec<String>>,
}

impl Config {
    pub fn parse(text: &str, home: &Path) -> Result<Self> {
        let raw: RawConfig = toml::from_str(text)?;
        let expand = |v: Vec<String>| v.iter().map(|s| expand_tilde(s, home)).collect();
        Ok(Self {
            roots: Roots {
                standalone: expand(raw.roots.standalone),
                containers: expand(raw.roots.containers),
                markers: raw.roots.markers,
            },
            identities: raw
                .identities
                .into_iter()
                .map(|(k, v)| {
                    let id = Identity {
                        name: v.name,
                        email: v.email,
                        ssh_key: v.ssh_key.map(|s| expand_tilde(&s, home)),
                    };
                    (k, id)
                })
                .collect(),
            accounts: raw.accounts,
        })
    }

    pub fn load(dirs: &Dirs) -> Result<Self> {
        let path = dirs.identity_toml();
        seed(&path)?;
        let text = fs::read_to_string(&path).with_context(|| {
            format!(
                "{} does not exist — declare your identities there",
                path.display()
            )
        })?;
        Self::parse(&text, &dirs.home)
            .with_context(|| format!("cannot parse {}", path.display()))
    }

    pub fn identity(&self, id: &str) -> Option<&Identity> {
        self.identities.get(id)
    }

    pub fn identity_names(&self) -> Vec<&str> {
        self.identities.keys().map(String::as_str).collect()
    }

    pub fn accounts_for(&self, tool: &str) -> &[String] {
        self.accounts.get(tool).map(Vec::as_slice).unwrap_or(&[])
    }
}

fn seed(dest: &Path) -> Result<()> {
    if dest.exists() {
        return Ok(());
    }
    let Some(src) = std::env::var_os("VJENV_TEMPLATE").filter(|s| !s.is_empty()) else {
        return Ok(());
    };
    let src = PathBuf::from(src);
    if !src.is_file() {
        return Ok(());
    }
    let contents = fs::read(&src)?;
    crate::paths::atomic_write(dest, &contents)?;
    let mut perms = fs::metadata(dest)?.permissions();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        perms.set_mode(0o644);
    }
    #[cfg(not(unix))]
    #[allow(clippy::permissions_set_readonly_false)]
    perms.set_readonly(false);
    fs::set_permissions(dest, perms)?;
    eprintln!(
        "vjenv: seeded {} — edit it to declare your identities and accounts",
        dest.display()
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"
        [roots]
        standalone = ["~/NewVideos", "~/nixconf"]
        containers = ["~/Projects"]
        markers = [".vjenv-root", ".VJCROOT"]

        [identities.goxore]
        name = "Yurii"
        email = "yurii@goxore.com"
        ssh_key = "~/.ssh/primary"

        [identities.vimjoyer]
        name = "Vimjoyer"
        email = "vimjoyer@gmail.com"
        ssh_key = "~/.ssh/id_rsa_vimjoyer"

        [accounts]
        claude = ["personal", "game"]
        codex  = ["main"]
    "#;

    fn sample() -> Config {
        Config::parse(SAMPLE, Path::new("/home/yurii")).unwrap()
    }

    #[test]
    fn parses_roots_with_tilde_expanded() {
        let c = sample();
        assert_eq!(
            c.roots.standalone,
            vec![
                PathBuf::from("/home/yurii/NewVideos"),
                PathBuf::from("/home/yurii/nixconf")
            ]
        );
        assert_eq!(c.roots.containers, vec![PathBuf::from("/home/yurii/Projects")]);
        assert_eq!(c.roots.markers, vec![".vjenv-root", ".VJCROOT"]);
    }

    #[test]
    fn parses_identities_and_accounts() {
        let c = sample();
        assert_eq!(c.identity_names(), vec!["goxore", "vimjoyer"]);
        let g = c.identity("goxore").unwrap();
        assert_eq!(g.name.as_deref(), Some("Yurii"));
        assert_eq!(g.email.as_deref(), Some("yurii@goxore.com"));
        assert_eq!(g.ssh_key, Some(PathBuf::from("/home/yurii/.ssh/primary")));

        assert_eq!(c.accounts_for("claude"), ["personal", "game"]);
        assert_eq!(c.accounts_for("codex"), ["main"]);
        assert!(c.accounts_for("nonexistent").is_empty());
    }

    #[test]
    fn empty_config_is_valid_and_yields_nothing() {
        let c = Config::parse("", Path::new("/home/yurii")).unwrap();
        assert!(c.identities.is_empty());
        assert!(c.roots.standalone.is_empty());
        assert!(c.accounts_for("claude").is_empty());
    }

    #[test]
    fn identity_may_omit_any_field() {
        let c = Config::parse("[identities.partial]\nname = \"Only Name\"", Path::new("/h")).unwrap();
        let p = c.identity("partial").unwrap();
        assert_eq!(p.name.as_deref(), Some("Only Name"));
        assert_eq!(p.email, None);
        assert_eq!(p.ssh_key, None);
    }

    #[test]
    fn malformed_toml_reports_where() {
        let err = Config::parse("[roots\nstandalone = 1", Path::new("/h")).unwrap_err();
        let msg = err.to_string();
        assert!(msg.contains("line") || msg.contains("expected"), "unhelpful error: {msg}");
    }
}
