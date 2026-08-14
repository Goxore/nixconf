use anyhow::{Result, bail};
use serde::Deserialize;
use std::path::Path;

pub const MARKER: &str = "vjtrees.toml";

pub const PLACEHOLDERS: &[&str] = &["root", "workspace", "name", "entry"];

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawConfig {
    project: RawProject,
    open: RawOpen,
    setup: Option<RawSetup>,
    server: Option<RawServer>,
    check: Option<RawCheck>,
    #[serde(default)]
    paths: RawPaths,
    #[serde(default)]
    backup: RawBackup,
    #[serde(default)]
    limits: RawLimits,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawProject {
    trunk: String,
    #[serde(default = "default_trunk_workspace")]
    trunk_workspace: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawOpen {
    command: Vec<String>,
    cwd: Option<String>,
    entry: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawSetup {
    command: Vec<String>,
    when_missing: Option<String>,
    when_newer: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawServer {
    command: Vec<String>,
    #[serde(default)]
    ports: Vec<u16>,
    #[serde(default)]
    wait_ports: Vec<u16>,
    wait_if_present: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawCheck {
    command: Vec<String>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawPaths {
    #[serde(default)]
    owned: Vec<String>,
    #[serde(default)]
    fragile: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawBackup {
    repository: Option<String>,
    #[serde(default = "default_encryption")]
    encryption: String,
    passphrase_command: Option<Vec<String>>,
    #[serde(default)]
    excludes: Vec<String>,
    #[serde(default = "default_keep_last")]
    keep_last: u32,
    #[serde(default = "default_keep_daily")]
    keep_daily: u32,
    #[serde(default)]
    prune: bool,
    #[serde(default)]
    require: Require,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields, rename_all = "kebab-case")]
struct RawLimits {
    #[serde(default = "default_ancestor_scan")]
    ancestor_scan: usize,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Require {
    #[default]
    Irreversible,
    Always,
    Never,
}

fn default_trunk_workspace() -> String {
    "default".to_string()
}

fn default_encryption() -> String {
    "none".to_string()
}

fn default_keep_last() -> u32 {
    50
}

fn default_keep_daily() -> u32 {
    30
}

fn default_ancestor_scan() -> usize {
    50
}

impl Default for RawBackup {
    fn default() -> Self {
        Self {
            repository: None,
            encryption: default_encryption(),
            passphrase_command: None,
            excludes: Vec::new(),
            keep_last: default_keep_last(),
            keep_daily: default_keep_daily(),
            prune: false,
            require: Require::default(),
        }
    }
}

impl Default for RawLimits {
    fn default() -> Self {
        Self {
            ancestor_scan: default_ancestor_scan(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Project {
    pub trunk: String,
    pub trunk_workspace: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Open {
    pub command: Vec<String>,
    pub cwd: Option<String>,
    pub entry: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Setup {
    pub command: Vec<String>,
    pub when_missing: Option<String>,
    pub when_newer: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Server {
    pub command: Vec<String>,
    pub ports: Vec<u16>,
    pub wait_ports: Vec<u16>,
    pub wait_if_present: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Check {
    pub command: Vec<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Paths {
    pub owned: Vec<String>,
    pub fragile: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Backup {
    pub repository: Option<String>,
    pub encryption: String,
    pub passphrase_command: Option<Vec<String>>,
    pub excludes: Vec<String>,
    pub keep_last: u32,
    pub keep_daily: u32,
    pub prune: bool,
    pub require: Require,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Limits {
    pub ancestor_scan: usize,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Config {
    pub project: Project,
    pub open: Open,
    pub setup: Option<Setup>,
    pub server: Option<Server>,
    pub check: Option<Check>,
    pub paths: Paths,
    pub backup: Backup,
    pub limits: Limits,
}

impl Config {
    pub fn parse(text: &str) -> Result<Self> {
        if text.trim().is_empty() {
            bail!(
                "{MARKER} is empty — vjtrees needs to know what this project looks like\n         \
                 write one with: vjtrees init"
            );
        }

        let raw: RawConfig = toml::from_str(text)?;
        let config = Self {
            project: Project {
                trunk: raw.project.trunk,
                trunk_workspace: raw.project.trunk_workspace,
            },
            open: Open {
                command: raw.open.command,
                cwd: raw.open.cwd,
                entry: raw.open.entry,
            },
            setup: raw.setup.map(|s| Setup {
                command: s.command,
                when_missing: s.when_missing,
                when_newer: s.when_newer,
            }),
            server: raw.server.map(|s| Server {
                command: s.command,
                ports: s.ports,
                wait_ports: s.wait_ports,
                wait_if_present: s.wait_if_present,
            }),
            check: raw.check.map(|c| Check { command: c.command }),
            paths: Paths {
                owned: raw.paths.owned,
                fragile: raw.paths.fragile,
            },
            backup: Backup {
                repository: raw.backup.repository,
                encryption: raw.backup.encryption,
                passphrase_command: raw.backup.passphrase_command,
                excludes: raw.backup.excludes,
                keep_last: raw.backup.keep_last,
                keep_daily: raw.backup.keep_daily,
                prune: raw.backup.prune,
                require: raw.backup.require,
            },
            limits: Limits {
                ancestor_scan: raw.limits.ancestor_scan,
            },
        };

        config.validate()?;
        Ok(config)
    }

    fn validate(&self) -> Result<()> {
        if self.project.trunk.trim().is_empty() {
            bail!("[project] trunk is empty — it must name the trunk workspace directory");
        }
        if Path::new(&self.project.trunk).components().count() != 1 {
            bail!(
                "[project] trunk must be a single directory name, not a path: {:?}",
                self.project.trunk
            );
        }
        if self.project.trunk_workspace.trim().is_empty() {
            bail!("[project] trunk-workspace is empty — it must name a jj workspace");
        }
        if self.open.command.is_empty() {
            bail!("[open] command is empty — it must at least name a program to run");
        }
        if self.limits.ancestor_scan == 0 {
            bail!("[limits] ancestor-scan must be at least 1");
        }
        if let Some(setup) = &self.setup
            && setup.command.is_empty()
        {
            bail!("[setup] command is empty — remove the section or give it a program");
        }
        if let Some(server) = &self.server {
            if server.command.is_empty() {
                bail!("[server] command is empty — remove the section or give it a program");
            }
            if server.ports.is_empty() {
                bail!(
                    "[server] ports is empty — vjtrees needs at least one port to know the server is up"
                );
            }
        }
        if let Some(check) = &self.check
            && check.command.is_empty()
        {
            bail!("[check] command is empty — remove the section or give it a program");
        }

        if let Some(repository) = &self.backup.repository
            && repository.trim().is_empty()
        {
            bail!("[backup] repository is empty — remove it or point it at a borg repository");
        }
        if self.backup.encryption.trim().is_empty() {
            bail!("[backup] encryption is empty — use \"none\" for an unencrypted repository");
        }
        if self.backup.encryption != "none" && self.backup.passphrase_command.is_none() {
            bail!(
                "[backup] encryption is {:?}, so passphrase-command must say how to obtain the passphrase",
                self.backup.encryption
            );
        }
        if let Some(command) = &self.backup.passphrase_command
            && command.is_empty()
        {
            bail!("[backup] passphrase-command is empty — remove it or give it a program");
        }
        for arg in &self.open.command {
            self.check_placeholders(arg, "[open] command")?;
        }
        if let Some(cwd) = &self.open.cwd {
            self.check_placeholders(cwd, "[open] cwd")?;
        }

        Ok(())
    }

    fn check_placeholders(&self, text: &str, where_: &str) -> Result<()> {
        for name in placeholders_in(text) {
            if !PLACEHOLDERS.contains(&name.as_str()) {
                bail!(
                    "{where_} uses unknown placeholder {{{name}}} — known ones are {}",
                    PLACEHOLDERS
                        .iter()
                        .map(|p| format!("{{{p}}}"))
                        .collect::<Vec<_>>()
                        .join(", ")
                );
            }
            if name == "entry" && self.open.entry.is_none() {
                bail!("{where_} uses {{entry}} but [open] entry is not set");
            }
        }
        Ok(())
    }
}

pub fn placeholders_in(text: &str) -> Vec<String> {
    let mut found = Vec::new();
    let mut rest = text;

    while let Some(start) = rest.find('{') {
        let after = &rest[start + 1..];
        match after.find('}') {
            Some(end) => {
                found.push(after[..end].to_string());
                rest = &after[end + 1..];
            }
            None => break,
        }
    }

    found
}

pub fn substitute(text: &str, values: &[(&str, &str)]) -> String {
    let mut out = text.to_string();
    for (name, value) in values {
        out = out.replace(&format!("{{{name}}}"), value);
    }
    out
}
