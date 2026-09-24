use anyhow::{Context, Result};
use std::env;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct Dirs {
    pub home: PathBuf,
    pub config: PathBuf,
    pub state: PathBuf,
    pub data: PathBuf,
    pub runtime: PathBuf,
}

fn xdg(var: &str, home: &Path, fallback: &str) -> PathBuf {
    vjcommon::xdg::dir(var, "vjenv", || home.join(fallback).join("vjenv"))
}

impl Dirs {
    pub fn from_env() -> Result<Self> {
        let home: PathBuf = env::var_os("HOME")
            .filter(|h| !h.is_empty())
            .map(PathBuf::from)
            .context("HOME is not set")?;
        Ok(Self {
            config: xdg("XDG_CONFIG_HOME", &home, ".config"),
            state: xdg("XDG_STATE_HOME", &home, ".local/state"),
            data: xdg("XDG_DATA_HOME", &home, ".local/share"),
            runtime: match env::var_os("XDG_RUNTIME_DIR") {
                Some(v) if !v.is_empty() => PathBuf::from(v).join("vjenv"),
                _ => PathBuf::from("/tmp/vjenv"),
            },
            home,
        })
    }

    pub fn identity_toml(&self) -> PathBuf {
        self.config.join("identity.toml")
    }
    pub fn registry(&self) -> PathBuf {
        self.state.join("projects.toml")
    }
    pub fn devshell(&self) -> PathBuf {
        self.state.join("devshell")
    }
    pub fn jj_config(&self, id: &str) -> PathBuf {
        self.runtime.join(format!("{id}.jj.toml"))
    }
    pub fn gh_config(&self, id: &str) -> PathBuf {
        self.data.join(id).join("gh")
    }
}

pub fn expand_tilde(s: &str, home: &Path) -> PathBuf {
    match s {
        "~" => home.to_path_buf(),
        _ => match s.strip_prefix("~/") {
            Some(rest) => home.join(rest),
            None => PathBuf::from(s),
        },
    }
}

pub use vjcommon::atomic::write as atomic_write;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tilde_expands_only_for_home_itself() {
        let home = Path::new("/home/yurii");
        assert_eq!(expand_tilde("~", home), home);
        assert_eq!(expand_tilde("~/nixconf", home), home.join("nixconf"));
        assert_eq!(expand_tilde("/abs/path", home), Path::new("/abs/path"));
        assert_eq!(expand_tilde("relative", home), Path::new("relative"));
        assert_eq!(expand_tilde("~other/x", home), Path::new("~other/x"));
    }

    #[test]
    fn dirs_lay_out_under_home_when_xdg_is_unset() {
        let home = Path::new("/h");
        let d = Dirs {
            home: home.to_path_buf(),
            config: xdg("VJENV_TEST_UNSET_VAR", home, ".config"),
            state: xdg("VJENV_TEST_UNSET_VAR", home, ".local/state"),
            data: xdg("VJENV_TEST_UNSET_VAR", home, ".local/share"),
            runtime: PathBuf::from("/run/user/1/vjenv"),
        };
        assert_eq!(
            d.identity_toml(),
            Path::new("/h/.config/vjenv/identity.toml")
        );
        assert_eq!(
            d.registry(),
            Path::new("/h/.local/state/vjenv/projects.toml")
        );
        assert_eq!(d.devshell(), Path::new("/h/.local/state/vjenv/devshell"));
        assert_eq!(
            d.jj_config("goxore"),
            Path::new("/run/user/1/vjenv/goxore.jj.toml")
        );
        assert_eq!(
            d.gh_config("goxore"),
            Path::new("/h/.local/share/vjenv/goxore/gh")
        );
    }
}
