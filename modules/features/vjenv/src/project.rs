use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use vjcommon::hex;

const DEVENV_FILES: &[&str] = &[
    "devenv.nix",
    "devenv.yaml",
    "devenv.lock",
    "devenv.local.nix",
    "devenv.local.yaml",
];

const FLAKE_FILES: &[&str] = &["flake.nix", "flake.lock"];

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
    let project = |kind, base: PathBuf| {
        Some(Project {
            dir: dir.into(),
            kind,
            base,
        })
    };
    if dir.join("devenv.nix").is_file() {
        project(Kind::Devenv, dir.into())
    } else if dir.join("flake.nix").is_file() {
        project(Kind::Flake, dir.into())
    } else if dir.join("flake/flake.nix").is_file() {
        project(Kind::Flake, dir.join("flake"))
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

    fn watched(&self) -> Vec<PathBuf> {
        match self.kind {
            Kind::Flake => FLAKE_FILES.iter().map(|f| self.base.join(f)).collect(),
            Kind::Devenv => {
                let inputs = std::fs::read_to_string(self.dir.join(".devenv/input-paths.txt"))
                    .unwrap_or_default();
                DEVENV_FILES
                    .iter()
                    .map(|f| self.dir.join(f))
                    .chain(inputs.lines().filter(|l| !l.is_empty()).map(PathBuf::from))
                    .collect()
            }
        }
    }

    pub fn stamp(&self) -> String {
        let mut h = Sha256::new();
        h.update(b"stamp-v2\n");
        for path in self.watched() {
            h.update(path.as_os_str().as_encoded_bytes());
            match std::fs::read(&path) {
                Ok(bytes) => {
                    h.update(format!(":{}\n", bytes.len()).as_bytes());
                    h.update(&bytes);
                }
                Err(_) => h.update(b":absent\n"),
            }
        }
        hex::encode(&h.finalize())
    }

    pub fn series(&self, installable: &str) -> String {
        let mut h = Sha256::new();
        h.update(b"series-v1\n");
        h.update(installable.as_bytes());
        hex::encode(&h.finalize())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn home() -> tempfile::TempDir {
        tempfile::tempdir().unwrap()
    }

    #[test]
    fn finds_a_flake_walking_upward() {
        let tmp = home();
        let home = tmp.path();
        std::fs::create_dir_all(home.join("proj/src/deep")).unwrap();
        std::fs::write(home.join("proj/flake.nix"), "{}").unwrap();

        let p = find(&home.join("proj/src/deep"), home).unwrap();
        assert_eq!(p.dir, home.join("proj"));
        assert_eq!(p.kind, Kind::Flake);
        assert_eq!(p.base, home.join("proj"));
    }

    #[test]
    fn finds_a_flake_in_a_flake_subdirectory() {
        let tmp = home();
        let home = tmp.path();
        std::fs::create_dir_all(home.join("proj/flake")).unwrap();
        std::fs::write(home.join("proj/flake/flake.nix"), "{}").unwrap();

        let p = find(&home.join("proj"), home).unwrap();
        assert_eq!(p.dir, home.join("proj"));
        assert_eq!(p.base, home.join("proj/flake"));
    }

    #[test]
    fn devenv_wins_over_a_flake_in_the_same_directory() {
        let tmp = home();
        let home = tmp.path();
        std::fs::create_dir_all(home.join("proj")).unwrap();
        std::fs::write(home.join("proj/flake.nix"), "{}").unwrap();
        std::fs::write(home.join("proj/devenv.nix"), "{}").unwrap();

        let p = find(&home.join("proj"), home).unwrap();
        assert_eq!(
            p.kind,
            Kind::Devenv,
            "a devenv project that also packages itself as a flake is still a devenv project"
        );
    }

    #[test]
    fn a_root_level_flake_takes_precedence_over_the_subdirectory() {
        let tmp = home();
        let home = tmp.path();
        std::fs::create_dir_all(home.join("proj/flake")).unwrap();
        std::fs::write(home.join("proj/flake.nix"), "{}").unwrap();
        std::fs::write(home.join("proj/flake/flake.nix"), "{}").unwrap();

        assert_eq!(
            find(&home.join("proj"), home).unwrap().base,
            home.join("proj")
        );
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
    fn the_series_survives_content_changes_but_not_a_different_shell() {
        let tmp = home();
        let dir = tmp.path();
        std::fs::write(dir.join("flake.nix"), "{}").unwrap();
        let p = find(dir, dir).unwrap();

        let before = p.series("x");
        std::fs::write(dir.join("flake.nix"), "{ changed = true; }").unwrap();
        assert_eq!(before, p.series("x"), "the series must span edits");
        assert_ne!(before, p.series("y"), "a different shell is its own series");
    }

    #[test]
    fn touching_a_file_without_changing_it_keeps_the_stamp() {
        let tmp = home();
        let dir = tmp.path();
        std::fs::write(dir.join("flake.nix"), "{}").unwrap();
        std::fs::write(dir.join("flake.lock"), "{}").unwrap();
        let p = find(dir, dir).unwrap();
        let before = p.stamp();

        let later = std::time::SystemTime::now() + std::time::Duration::from_secs(120);
        std::fs::File::options()
            .write(true)
            .open(dir.join("flake.lock"))
            .unwrap()
            .set_modified(later)
            .unwrap();

        assert_eq!(
            before,
            p.stamp(),
            "a checkout that only rewrites mtimes must not force re-evaluation"
        );
    }

    #[test]
    fn the_search_stops_at_home() {
        let tmp = home();
        let outside = tmp.path();
        let home = outside.join("home");
        std::fs::create_dir_all(home.join("proj")).unwrap();
        std::fs::write(outside.join("flake.nix"), "{}").unwrap();

        assert_eq!(find(&home.join("proj"), &home), None);
    }

    #[test]
    fn a_flake_stamp_follows_the_lock_file() {
        let tmp = home();
        let dir = tmp.path();
        std::fs::write(dir.join("flake.nix"), "{}").unwrap();
        let p = find(dir, dir).unwrap();

        let bare = p.stamp();
        assert_eq!(bare, p.stamp(), "an untouched project keeps its stamp");

        std::fs::write(dir.join("flake.lock"), "{}").unwrap();
        assert_ne!(bare, p.stamp(), "adding a lockfile must change the stamp");

        std::fs::remove_file(dir.join("flake.lock")).unwrap();
        assert_eq!(bare, p.stamp(), "removing it again must restore the stamp");
    }

    #[test]
    fn a_devenv_stamp_follows_the_files_devenv_reports_reading() {
        let tmp = home();
        let dir = tmp.path();
        std::fs::create_dir_all(dir.join(".devenv")).unwrap();
        std::fs::write(dir.join("devenv.nix"), "{}").unwrap();
        let imported = dir.join("nix/shell.nix");
        std::fs::create_dir_all(imported.parent().unwrap()).unwrap();
        std::fs::write(&imported, "{}").unwrap();
        std::fs::write(
            dir.join(".devenv/input-paths.txt"),
            format!("{}\n", imported.display()),
        )
        .unwrap();
        let p = find(dir, dir).unwrap();

        let before = p.stamp();
        std::fs::write(&imported, "{ changed = true; }").unwrap();
        assert_ne!(before, p.stamp(), "an imported file is part of the project");

        let settled = p.stamp();
        std::fs::write(dir.join("devenv.local.nix"), "{}").unwrap();
        assert_ne!(
            settled,
            p.stamp(),
            "local overrides are part of the project"
        );
    }
}
