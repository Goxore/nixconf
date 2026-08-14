#![allow(dead_code)]

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use tempfile::TempDir;
use vjtrees::jj::Jj;
use vjtrees::root::Root;

pub const VJCANVAS_SHAPED: &str = r#"
[project]
trunk = "vjcanvas"
trunk-workspace = "default"

[open]
command = ["nvim", "{workspace}"]

[paths]
owned = ["video/"]
fragile = ["src/dsl/", "package.json"]

[backup]
require = "never"
"#;

pub const DIFFERENTLY_SHAPED: &str = r#"
[project]
trunk = "main"
trunk-workspace = "trunk"

[open]
command = ["hx", "{workspace}"]

[paths]
owned = ["docs/"]
fragile = ["lib/"]

[limits]
ancestor-scan = 25

[backup]
require = "never"
"#;

pub fn vjcanvas_shaped_requiring(require: &str) -> String {
    VJCANVAS_SHAPED.replace(r#"require = "never""#, &format!(r#"require = "{require}""#))
}

pub fn vjcanvas_shaped_backing_up_to(require: &str, repository: &str) -> String {
    format!(
        "{}repository = \"{repository}\"\n",
        vjcanvas_shaped_requiring(require)
    )
}

pub struct Fixture {
    pub root: Root,
    pub jj: Jj,
    _dir: TempDir,
}

pub fn require_jj() {
    let ok = Command::new("jj")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    assert!(
        ok,
        "jj is not runnable — these tests exercise real jj behaviour and \
         skipping them would hide exactly the regressions they exist to catch"
    );
}

pub fn require_borg() {
    let ok = Command::new("borg")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    assert!(
        ok,
        "borg is not runnable — these tests exercise the real borg CLI and \
         skipping them would hide exactly the regressions they exist to catch"
    );
}

fn run(program: &str, args: &[&str], cwd: &Path) -> String {
    let output = Command::new(program)
        .args(args)
        .current_dir(cwd)
        .output()
        .unwrap_or_else(|e| panic!("could not run {program}: {e}"));

    assert!(
        output.status.success(),
        "{program} {args:?} failed in {}:\n{}",
        cwd.display(),
        String::from_utf8_lossy(&output.stderr)
    );

    String::from_utf8_lossy(&output.stdout).trim().to_string()
}

impl Fixture {
    pub fn new(config: &str) -> Self {
        require_jj();

        let dir = TempDir::new().expect("tempdir");
        let base = dir.path().to_path_buf();

        fs::write(base.join(vjtrees::config::MARKER), config).expect("write marker");

        let parsed = vjtrees::config::Config::parse(config).expect("fixture config parses");
        let trunk = base.join(&parsed.project.trunk);
        fs::create_dir_all(&trunk).expect("create trunk");

        run("jj", &["git", "init", "."], &trunk);
        run(
            "jj",
            &["config", "set", "--repo", "user.name", "vjtrees test"],
            &trunk,
        );
        run(
            "jj",
            &[
                "config",
                "set",
                "--repo",
                "user.email",
                "vjtrees@test.invalid",
            ],
            &trunk,
        );

        if parsed.project.trunk_workspace != "default" {
            run(
                "jj",
                &["workspace", "rename", &parsed.project.trunk_workspace],
                &trunk,
            );
        }

        let root = Root::find(&base).expect("fixture root resolves");
        let jj = Jj::new(&root.trunk);

        Self {
            root,
            jj,
            _dir: dir,
        }
    }

    pub fn vjcanvas_shaped() -> Self {
        Self::new(VJCANVAS_SHAPED)
    }

    pub fn differently_shaped() -> Self {
        Self::new(DIFFERENTLY_SHAPED)
    }

    pub fn dir_of(&self, workspace: &str) -> PathBuf {
        if workspace == self.root.trunk_workspace() {
            self.root.trunk.clone()
        } else {
            self.root.workspace_path(workspace)
        }
    }

    pub fn jj_in(&self, workspace: &str, args: &[&str]) -> String {
        run("jj", args, &self.dir_of(workspace))
    }

    pub fn commit(&self, workspace: &str, file: &str, body: &str, message: &str) {
        let dir = self.dir_of(workspace);
        let full = dir.join(file);
        if let Some(parent) = full.parent() {
            fs::create_dir_all(parent).expect("create parent");
        }
        fs::write(&full, body).expect("write file");
        self.jj_in(workspace, &["describe", "-m", message]);
    }

    pub fn new_change(&self, workspace: &str) {
        self.jj_in(workspace, &["new"]);
    }

    pub fn add_workspace(&self, name: &str, revset: &str) {
        let dir = self.root.workspace_path(name);
        self.jj
            .workspace_add(&dir, name, Some(revset))
            .expect("workspace add");
    }

    pub fn commit_of(&self, description: &str) -> String {
        let out = self.jj_in(
            self.root.trunk_workspace(),
            &[
                "log",
                "-r",
                "all()",
                "--no-graph",
                "--ignore-working-copy",
                "-T",
                r#"commit_id ++ "\t" ++ description.first_line() ++ "\n""#,
            ],
        );

        out.lines()
            .filter_map(|line| line.split_once('\t'))
            .find(|(_, desc)| *desc == description)
            .unwrap_or_else(|| panic!("no change described {description:?} in:\n{out}"))
            .0
            .to_string()
    }

    pub fn parents_of(&self, revset: &str) -> Vec<String> {
        self.jj_in(
            self.root.trunk_workspace(),
            &[
                "log",
                "-r",
                revset,
                "--no-graph",
                "--ignore-working-copy",
                "-T",
                r#"parents.map(|p| p.commit_id()).join(" ")"#,
            ],
        )
        .split_whitespace()
        .map(str::to_string)
        .collect()
    }

    pub fn diverge(&self, description: &str) -> String {
        let trunk = self.root.trunk_workspace().to_string();
        let before = self.jj.op_head().expect("op head");

        self.jj_in(&trunk, &["describe", "--at-op", &before, "-m", description]);
        self.jj_in(
            &trunk,
            &["describe", "--at-op", &before, "-m", "the other rewrite"],
        );

        let divergent = self.jj.divergent().expect("divergent query");
        assert!(
            divergent.len() >= 2,
            "the fixture must actually produce divergence, got {divergent:?}"
        );

        divergent[0].change_id.clone()
    }

    pub fn make_stale(&self, workspace: &str, onto: &str) {
        self.commit(
            workspace,
            "workspace-work.txt",
            "content",
            "work in the workspace",
        );
        self.new_change(workspace);

        let moving = self.commit_of("work in the workspace");
        self.jj
            .rebase(
                vjtrees::jj::Moving::Subtree(&moving),
                vjtrees::jj::Placement::Onto(onto),
            )
            .expect("rebase issued from the root");

        assert_eq!(
            self.jj.working_copy_state(&self.dir_of(workspace)).ok(),
            Some(vjtrees::jj::WorkingCopy::Stale),
            "the fixture must actually leave {workspace} stale"
        );
    }

    pub fn descriptions(&self) -> Vec<String> {
        self.jj_in(
            self.root.trunk_workspace(),
            &[
                "log",
                "-r",
                "all()",
                "--no-graph",
                "--ignore-working-copy",
                "-T",
                r#"description.first_line() ++ "\n""#,
            ],
        )
        .lines()
        .map(str::to_string)
        .collect()
    }
}
