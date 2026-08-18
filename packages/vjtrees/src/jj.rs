use anyhow::{Context, Result, bail};
use std::path::{Path, PathBuf};
use std::process::Command;

const CHANGE_TEMPLATE: &str = concat!(
    r#"commit_id ++ "\t" ++ change_id.short() ++ "\t" "#,
    r#"++ if(divergent,"1","0") ++ "\t" "#,
    r#"++ if(description,"1","0") ++ "\t" "#,
    r#"++ description.first_line() ++ "\n""#,
);

const WORKSPACE_TEMPLATE: &str = concat!(
    r#"name ++ "\t" ++ target.commit_id() ++ "\t" "#,
    r#"++ target.change_id().short() ++ "\t" "#,
    r#"++ if(target.divergent(),"1","0") ++ "\t" "#,
    r#"++ target.description().first_line() ++ "\n""#,
);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Change {
    pub commit_id: String,
    pub change_id: String,
    pub divergent: bool,
    pub described: bool,
    pub description: String,
}

impl Change {
    pub fn label(&self) -> String {
        if self.description.is_empty() {
            format!("{} (no description set)", self.change_id)
        } else {
            format!("{} {}", self.change_id, self.description)
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Workspace {
    pub name: String,
    pub commit_id: String,
    pub change_id: String,
    pub divergent: bool,
    pub description: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Operation {
    pub id: String,
    pub description: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WorkingCopy {
    Clean,
    Modified,
    Stale,
}

#[derive(Debug)]
struct Output {
    stdout: String,
    stderr: String,
    code: i32,
}

impl Output {
    fn ok(&self) -> bool {
        self.code == 0
    }

    fn first_error_line(&self) -> String {
        self.stderr
            .lines()
            .map(str::trim)
            .find(|l| !l.is_empty())
            .unwrap_or("no output")
            .to_string()
    }
}

pub fn quote_workspace(name: &str) -> String {
    let escaped = name.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"@")
}

#[derive(Debug, Clone)]
pub struct Jj {
    repo: PathBuf,
}

impl Jj {
    pub fn new(repo: &Path) -> Self {
        Self {
            repo: repo.to_path_buf(),
        }
    }

    fn exec(&self, dir: &Path, args: &[&str]) -> Result<Output> {
        let output = Command::new("jj")
            .args(["--no-pager", "-R"])
            .arg(dir)
            .args(args)
            .output()
            .context(
                "could not run jj — it should be on PATH via the vjtrees wrapper, \
                 so this means the wrapper is broken",
            )?;

        Ok(Output {
            stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
            stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
            code: output.status.code().unwrap_or(-1),
        })
    }

    fn read(&self, args: &[&str]) -> Result<Output> {
        let mut full = vec!["--ignore-working-copy"];
        full.extend_from_slice(args);
        self.exec(&self.repo.clone(), &full)
    }

    fn read_ok(&self, args: &[&str], what: &str) -> Result<String> {
        let out = self.read(args)?;
        if !out.ok() {
            bail!("{what}: {}", out.first_error_line());
        }
        Ok(out.stdout)
    }

    pub fn version(&self) -> Result<String> {
        let output = Command::new("jj")
            .arg("--version")
            .output()
            .context("could not run jj")?;

        if !output.status.success() {
            bail!("jj --version failed");
        }

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    pub fn workspaces(&self) -> Result<Vec<Workspace>> {
        let stdout = self.read_ok(
            &["workspace", "list", "-T", WORKSPACE_TEMPLATE],
            "cannot list jj workspaces",
        )?;

        stdout
            .lines()
            .filter(|l| !l.is_empty())
            .map(|line| {
                let f: Vec<&str> = line.splitn(5, '\t').collect();
                if f.len() < 5 {
                    bail!("unexpected `jj workspace list` output: {line:?}");
                }
                Ok(Workspace {
                    name: f[0].to_string(),
                    commit_id: f[1].to_string(),
                    change_id: f[2].to_string(),
                    divergent: f[3] == "1",
                    description: f[4].to_string(),
                })
            })
            .collect()
    }

    fn changes(&self, args: &[&str], what: &str) -> Result<Vec<Change>> {
        let stdout = self.read_ok(args, what)?;
        parse_changes(&stdout)
    }

    pub fn resolve(&self, revset: &str) -> Result<Option<Change>> {
        let found = self.changes(
            &[
                "log",
                "-r",
                revset,
                "-n",
                "1",
                "--no-graph",
                "-T",
                CHANGE_TEMPLATE,
            ],
            &format!("cannot resolve {revset}"),
        )?;
        Ok(found.into_iter().next())
    }

    pub fn merge_base(&self, a: &str, b: &str) -> Result<Option<Change>> {
        self.resolve(&format!("heads(::({a}) & ::({b}))"))
    }

    pub fn is_ancestor(&self, ancestor: &str, descendant: &str) -> Result<bool> {
        let stdout = self.read_ok(
            &[
                "log",
                "-r",
                &format!("({ancestor}) & ::({descendant})"),
                "--no-graph",
                "-T",
                r#""x\n""#,
            ],
            &format!("cannot tell whether {ancestor} is an ancestor of {descendant}"),
        )?;

        Ok(!stdout.trim().is_empty())
    }

    pub fn count_ancestors(&self, revset: &str) -> Result<usize> {
        let stdout = self.read_ok(
            &[
                "log",
                "-r",
                &format!("::({revset})"),
                "--no-graph",
                "-T",
                r#""x\n""#,
            ],
            &format!("cannot count ancestors of {revset}"),
        )?;

        Ok(stdout.lines().filter(|l| !l.is_empty()).count())
    }

    pub fn commits_between(&self, from: &str, to: &str) -> Result<Vec<Change>> {
        self.changes(
            &[
                "log",
                "-r",
                &format!("({from})..({to})"),
                "--reversed",
                "--no-graph",
                "-T",
                CHANGE_TEMPLATE,
            ],
            &format!("cannot list changes between {from} and {to}"),
        )
    }

    pub fn ancestors(&self, revset: &str, limit: usize) -> Result<Vec<Change>> {
        self.changes(
            &[
                "log",
                "-r",
                &format!("ancestors({revset})"),
                "-n",
                &limit.to_string(),
                "--no-graph",
                "-T",
                CHANGE_TEMPLATE,
            ],
            &format!("cannot read the ancestors of {revset}"),
        )
    }

    pub fn divergent(&self) -> Result<Vec<Change>> {
        self.changes(
            &[
                "log",
                "-r",
                "divergent()",
                "--no-graph",
                "-T",
                CHANGE_TEMPLATE,
            ],
            "cannot check for divergent changes",
        )
    }

    pub fn changed_files(&self, revset: &str) -> Result<Vec<String>> {
        let stdout = self.read_ok(
            &["diff", "-r", revset, "--name-only"],
            &format!("cannot list the files changed by {revset}"),
        )?;

        Ok(stdout
            .lines()
            .map(str::trim)
            .filter(|l| !l.is_empty())
            .map(str::to_string)
            .collect())
    }

    pub fn diff_stat(&self, revset: &str) -> Result<String> {
        let stdout = self.read_ok(
            &["diff", "-r", revset, "--stat"],
            &format!("cannot diff {revset}"),
        )?;
        Ok(stdout.trim_end().to_string())
    }

    pub fn op_head(&self) -> Result<String> {
        let stdout = self.read_ok(
            &[
                "op",
                "log",
                "-n",
                "1",
                "--no-graph",
                "-T",
                r#"id.short() ++ "\n""#,
            ],
            "cannot read the jj operation log",
        )?;

        let id = stdout.trim();
        if id.is_empty() {
            bail!("the jj operation log is empty");
        }

        Ok(id.to_string())
    }

    pub fn ops_since(&self, op_id: &str, limit: usize) -> Result<Vec<Operation>> {
        let stdout = self.read_ok(
            &[
                "op",
                "log",
                "-n",
                &limit.to_string(),
                "--no-graph",
                "-T",
                r#"id.short() ++ "\t" ++ description ++ "\n""#,
            ],
            "cannot read the jj operation log",
        )?;

        let mut ops = Vec::new();
        for line in stdout.lines().filter(|l| !l.is_empty()) {
            let (id, description) = line.split_once('\t').unwrap_or((line, ""));
            if id == op_id {
                return Ok(ops);
            }
            ops.push(Operation {
                id: id.to_string(),
                description: description.to_string(),
            });
        }

        Ok(ops)
    }

    pub fn working_copy_state(&self, workspace_dir: &Path) -> Result<WorkingCopy> {
        let out = self.exec(workspace_dir, &["diff", "--summary"])?;

        if out.ok() {
            return Ok(if out.stdout.trim().is_empty() {
                WorkingCopy::Clean
            } else {
                WorkingCopy::Modified
            });
        }

        let stderr = out.stderr.to_lowercase();
        if stderr.contains("working copy is stale") || stderr.contains("update-stale") {
            return Ok(WorkingCopy::Stale);
        }

        bail!(
            "jj cannot read the working copy at {}: {}",
            workspace_dir.display(),
            out.first_error_line()
        )
    }

    pub fn update_stale(&self, workspace_dir: &Path) -> Result<bool> {
        let out = self.exec(workspace_dir, &["workspace", "update-stale"])?;

        if !out.ok() {
            bail!(
                "cannot update {}: {}",
                workspace_dir.display(),
                out.first_error_line()
            );
        }

        let combined = format!("{}{}", out.stderr, out.stdout).to_lowercase();
        Ok(!combined.contains("not stale"))
    }

    pub fn new_change(&self, revset: Option<&str>) -> Result<()> {
        let mut args = vec!["new"];
        if let Some(revset) = revset {
            args.push("-r");
            args.push(revset);
        }

        let out = self.exec(&self.repo.clone(), &args)?;
        if !out.ok() {
            bail!("jj new failed: {}", out.first_error_line());
        }

        Ok(())
    }

    pub fn describe(&self, revset: &str, message: &str) -> Result<()> {
        let out = self.exec(
            &self.repo.clone(),
            &["describe", "-r", revset, "-m", message],
        )?;
        if !out.ok() {
            bail!("jj describe failed: {}", out.first_error_line());
        }
        Ok(())
    }

    pub fn abandon(&self, commit_id: &str) -> Result<()> {
        let out = self.exec(&self.repo.clone(), &["abandon", commit_id])?;
        if !out.ok() {
            bail!("jj abandon {commit_id} failed: {}", out.first_error_line());
        }
        Ok(())
    }

    pub fn workspace_add(&self, dir: &Path, name: &str, revset: Option<&str>) -> Result<()> {
        let dir_str = dir.to_string_lossy().into_owned();
        let mut args = vec!["workspace", "add", &dir_str, "--name", name];
        if let Some(revset) = revset {
            args.push("-r");
            args.push(revset);
        }

        let out = self.exec(&self.repo.clone(), &args)?;
        if !out.ok() {
            bail!("jj workspace add failed: {}", out.first_error_line());
        }
        Ok(())
    }

    pub fn workspace_forget(&self, name: &str) -> Result<()> {
        let out = self.exec(&self.repo.clone(), &["workspace", "forget", name])?;
        if !out.ok() {
            bail!(
                "jj workspace forget {name} failed: {}",
                out.first_error_line()
            );
        }
        Ok(())
    }

    pub fn op_restore(&self, op_id: &str) -> Result<()> {
        let out = self.exec(&self.repo.clone(), &["op", "restore", op_id])?;
        if !out.ok() {
            bail!("jj op restore {op_id} failed: {}", out.first_error_line());
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Placement<'a> {
    Onto(&'a str),
    Before(&'a str),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Moving<'a> {
    Subtree(&'a str),
    Single(&'a str),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RebaseOutcome {
    pub conflicted: bool,
}

impl Jj {
    pub fn rebase(&self, moving: Moving<'_>, placement: Placement<'_>) -> Result<RebaseOutcome> {
        let mut args = vec!["rebase"];

        match moving {
            Moving::Subtree(revset) => {
                args.push("-s");
                args.push(revset);
            }
            Moving::Single(revset) => {
                args.push("-r");
                args.push(revset);
            }
        }

        match placement {
            Placement::Onto(revset) => {
                args.push("-d");
                args.push(revset);
            }
            Placement::Before(revset) => {
                args.push("--insert-before");
                args.push(revset);
            }
        }

        let out = self.exec(&self.repo.clone(), &args)?;

        if !out.ok() {
            if out.stderr.to_lowercase().contains("conflict") {
                return Ok(RebaseOutcome { conflicted: true });
            }
            bail!("jj rebase failed: {}", out.first_error_line());
        }

        Ok(RebaseOutcome {
            conflicted: out.stderr.to_lowercase().contains("conflict"),
        })
    }
}

pub fn parse_changes(stdout: &str) -> Result<Vec<Change>> {
    stdout
        .lines()
        .filter(|l| !l.is_empty())
        .map(|line| {
            let f: Vec<&str> = line.splitn(5, '\t').collect();
            if f.len() < 5 {
                bail!("unexpected `jj log` output: {line:?}");
            }
            Ok(Change {
                commit_id: f[0].to_string(),
                change_id: f[1].to_string(),
                divergent: f[2] == "1",
                described: f[3] == "1",
                description: f[4].to_string(),
            })
        })
        .collect()
}
