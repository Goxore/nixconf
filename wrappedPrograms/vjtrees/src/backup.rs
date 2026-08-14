use crate::config::Backup;
use crate::root::Root;
use anyhow::{Context, Result, bail};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

const ARCHIVE_PREFIX: &str = "vjtrees";
const LOCK_WAIT_SECONDS: &str = "10";

pub fn is_configured(config: &Backup) -> bool {
    config.repository.is_some()
}

pub fn repository(config: &Backup) -> Result<&str> {
    config
        .repository
        .as_deref()
        .context("no [backup] repository is set in vjtrees.toml")
}

fn passphrase(config: &Backup) -> Result<Option<String>> {
    let Some(command) = &config.passphrase_command else {
        return Ok(None);
    };

    let (program, args) = command
        .split_first()
        .context("[backup] passphrase-command is empty")?;

    let output = Command::new(program)
        .args(args)
        .output()
        .with_context(|| format!("could not run passphrase-command {program}"))?;

    if !output.status.success() {
        bail!(
            "passphrase-command {program} failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }

    let secret = String::from_utf8_lossy(&output.stdout)
        .trim_end_matches('\n')
        .to_string();

    if secret.is_empty() {
        bail!("passphrase-command {program} produced nothing");
    }

    Ok(Some(secret))
}

fn env(config: &Backup) -> Result<BTreeMap<String, String>> {
    let mut env = BTreeMap::new();
    env.insert(
        "BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK".to_string(),
        "yes".to_string(),
    );
    env.insert(
        "BORG_RELOCATED_REPO_ACCESS_IS_OK".to_string(),
        "yes".to_string(),
    );

    if let Some(secret) = passphrase(config)? {
        env.insert("BORG_PASSPHRASE".to_string(), secret);
    }

    Ok(env)
}

fn borg(env: &BTreeMap<String, String>, args: &[&str]) -> Result<(bool, String, String)> {
    let output = Command::new("borg")
        .arg("--lock-wait")
        .arg(LOCK_WAIT_SECONDS)
        .args(args)
        .envs(env)
        .output()
        .context("could not run borg — it should be on PATH via the vjtrees wrapper")?;

    Ok((
        output.status.success(),
        String::from_utf8_lossy(&output.stdout).into_owned(),
        String::from_utf8_lossy(&output.stderr).into_owned(),
    ))
}

pub fn is_lock_failure(stderr: &str) -> bool {
    stderr.contains("Failed to create/acquire the lock")
        || stderr.contains("LockTimeout")
        || stderr.contains("lock.exclusive")
}

fn failed(action: &str, repository: &str, stderr: &str) -> anyhow::Error {
    let trimmed = stderr.trim();

    if is_lock_failure(stderr) {
        return anyhow::anyhow!(
            "borg {action} could not lock the repository — another borg is running, \
             or a previous one died holding the lock\n       \
             if nothing else is running: borg break-lock {repository}\n       {trimmed}"
        );
    }

    anyhow::anyhow!("borg {action} failed: {trimmed}")
}

fn repository_exists(repository: &str) -> bool {
    Path::new(repository).join("config").is_file()
}

fn ensure_repository(config: &Backup) -> Result<()> {
    let repository = repository(config)?;
    if repository_exists(repository) {
        return Ok(());
    }

    if let Some(parent) = Path::new(repository).parent() {
        std::fs::create_dir_all(parent)
            .with_context(|| format!("could not create the directory holding {repository}"))?;
    }

    let environment = env(config)?;
    let encryption = format!("--encryption={}", config.encryption);
    let (ok, _, stderr) = borg(&environment, &["init", &encryption, repository])?;

    if !ok && !stderr.contains("already exists") {
        return Err(failed("init", repository, &stderr));
    }

    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Snapshot {
    pub id: String,
}

pub fn run_backup(root: &Root, config: &Backup) -> Result<Snapshot> {
    ensure_repository(config)?;

    let repository = repository(config)?;
    let environment = env(config)?;
    let target = format!("{repository}::{ARCHIVE_PREFIX}-{{now:%Y-%m-%dT%H-%M-%S-%f}}");
    let root_str = root.root.to_string_lossy().into_owned();

    let mut args = vec!["create", "--json", target.as_str(), root_str.as_str()];
    for exclude in &config.excludes {
        args.push("--exclude");
        args.push(exclude);
    }

    let (ok, stdout, stderr) = borg(&environment, &args)?;
    if !ok {
        return Err(failed("create", repository, &stderr));
    }

    Ok(Snapshot {
        id: archive_name_from(&stdout).unwrap_or_else(|| "unknown".to_string()),
    })
}

pub fn archive_name_from(stdout: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(stdout.trim()).ok()?;
    value
        .get("archive")?
        .get("name")?
        .as_str()
        .map(str::to_string)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Archive {
    pub name: String,
    pub start: String,
}

pub fn archives(config: &Backup) -> Result<Vec<Archive>> {
    let repository = repository(config)?;
    if !repository_exists(repository) {
        return Ok(Vec::new());
    }

    let environment = env(config)?;
    let glob = format!("{ARCHIVE_PREFIX}-*");
    let (ok, stdout, stderr) = borg(
        &environment,
        &["list", "--json", "--glob-archives", &glob, repository],
    )?;

    if !ok {
        return Err(failed("list", repository, &stderr));
    }

    Ok(parse_archives(&stdout))
}

pub fn parse_archives(stdout: &str) -> Vec<Archive> {
    let Ok(value) = serde_json::from_str::<serde_json::Value>(stdout.trim()) else {
        return Vec::new();
    };

    let Some(list) = value.get("archives").and_then(|a| a.as_array()) else {
        return Vec::new();
    };

    list.iter()
        .filter_map(|entry| {
            Some(Archive {
                name: entry.get("archive")?.as_str()?.to_string(),
                start: entry
                    .get("start")
                    .and_then(|s| s.as_str())
                    .unwrap_or("")
                    .to_string(),
            })
        })
        .collect()
}

pub fn latest(config: &Backup) -> Result<Option<Archive>> {
    Ok(archives(config)?.pop())
}

pub fn restore(config: &Backup, archive: &str, into: &Path, paths: &[String]) -> Result<PathBuf> {
    let repository = repository(config)?;
    let environment = env(config)?;

    std::fs::create_dir_all(into)
        .with_context(|| format!("could not create {}", into.display()))?;

    if std::fs::read_dir(into)?.next().is_some() {
        bail!(
            "{} is not empty — restore needs somewhere it cannot overwrite your work",
            into.display()
        );
    }

    let target = format!("{repository}::{archive}");
    let mut args = vec!["extract", target.as_str()];
    for path in paths {
        args.push(path.trim_start_matches('/'));
    }

    let output = Command::new("borg")
        .arg("--lock-wait")
        .arg(LOCK_WAIT_SECONDS)
        .args(&args)
        .envs(&environment)
        .current_dir(into)
        .output()
        .context("could not run borg — it should be on PATH via the vjtrees wrapper")?;

    if !output.status.success() {
        return Err(failed(
            "extract",
            repository,
            &String::from_utf8_lossy(&output.stderr),
        ));
    }

    Ok(into.to_path_buf())
}

pub fn contents(config: &Backup, archive: &str) -> Result<Vec<String>> {
    let repository = repository(config)?;
    let environment = env(config)?;
    let target = format!("{repository}::{archive}");

    let (ok, stdout, stderr) = borg(&environment, &["list", "--short", &target])?;
    if !ok {
        return Err(failed("list", repository, &stderr));
    }

    Ok(stdout.lines().map(str::to_string).collect())
}

pub fn forget(config: &Backup) -> Result<String> {
    let repository = repository(config)?;
    if !repository_exists(repository) {
        bail!("there is no borg repository at {repository} yet");
    }

    let environment = env(config)?;
    let keep_last = config.keep_last.to_string();
    let keep_daily = config.keep_daily.to_string();
    let glob = format!("{ARCHIVE_PREFIX}-*");

    let (ok, stdout, stderr) = borg(
        &environment,
        &[
            "prune",
            "--list",
            "--keep-last",
            keep_last.as_str(),
            "--keep-daily",
            keep_daily.as_str(),
            "--glob-archives",
            glob.as_str(),
            repository,
        ],
    )?;

    if !ok {
        return Err(failed("prune", repository, &stderr));
    }

    let mut report = if stdout.trim().is_empty() {
        stderr
    } else {
        stdout
    };

    if config.prune {
        let (ok, _, stderr) = borg(&environment, &["compact", repository])?;
        if !ok {
            return Err(failed("compact", repository, &stderr));
        }
        report.push_str("\ncompacted — freed space is no longer recoverable");
    }

    Ok(report)
}
