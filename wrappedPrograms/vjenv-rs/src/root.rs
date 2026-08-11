use crate::config::Roots;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RootKind {
    Standalone,
    Marker,
    Container,
    Vcs,
}

impl RootKind {
    pub fn as_str(self) -> &'static str {
        match self {
            RootKind::Standalone => "standalone",
            RootKind::Marker => "marker",
            RootKind::Container => "container",
            RootKind::Vcs => "vcs",
        }
    }
}

pub trait Probe {
    fn exists(&self, path: &Path) -> bool;
}

pub struct RealFs;

impl Probe for RealFs {
    fn exists(&self, path: &Path) -> bool {
        path.symlink_metadata().is_ok()
    }
}

pub fn resolve(start: &Path, roots: &Roots, probe: &impl Probe) -> Option<(PathBuf, RootKind)> {
    for dir in start.ancestors() {
        if roots.standalone.iter().any(|s| s == dir) {
            return Some((dir.to_path_buf(), RootKind::Standalone));
        }
        if roots.markers.iter().any(|m| probe.exists(&dir.join(m))) {
            return Some((dir.to_path_buf(), RootKind::Marker));
        }
        if let Some(parent) = dir.parent() {
            if roots.containers.iter().any(|c| c == parent) {
                return Some((dir.to_path_buf(), RootKind::Container));
            }
        }
    }
    for dir in start.ancestors() {
        if probe.exists(&dir.join(".git")) || probe.exists(&dir.join(".jj")) {
            return Some((dir.to_path_buf(), RootKind::Vcs));
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeSet;

    struct FakeFs(BTreeSet<PathBuf>);

    impl FakeFs {
        fn new(paths: &[&str]) -> Self {
            Self(paths.iter().map(PathBuf::from).collect())
        }
    }

    impl Probe for FakeFs {
        fn exists(&self, path: &Path) -> bool {
            self.0.contains(path)
        }
    }

    fn roots() -> Roots {
        Roots {
            standalone: vec!["/h/NewVideos".into(), "/h/nixconf".into()],
            containers: vec!["/h/Projects".into()],
            markers: vec![".vjenv-root".into(), ".VJCROOT".into()],
        }
    }

    fn resolve_at(start: &str, files: &[&str]) -> Option<(PathBuf, RootKind)> {
        resolve(Path::new(start), &roots(), &FakeFs::new(files))
    }

    #[test]
    fn standalone_matches_itself_and_its_children() {
        assert_eq!(
            resolve_at("/h/nixconf", &[]),
            Some(("/h/nixconf".into(), RootKind::Standalone))
        );
        assert_eq!(
            resolve_at("/h/nixconf/wrappedPrograms/vjenv-rs", &[]),
            Some(("/h/nixconf".into(), RootKind::Standalone))
        );
    }

    #[test]
    fn container_children_are_roots_but_the_container_is_not() {
        assert_eq!(
            resolve_at("/h/Projects/secretspec/src/deep", &[]),
            Some(("/h/Projects/secretspec".into(), RootKind::Container))
        );
        assert_eq!(resolve_at("/h/Projects", &[]), None);
    }

    #[test]
    fn a_marker_makes_any_directory_a_root() {
        assert_eq!(
            resolve_at("/somewhere/else/deep", &["/somewhere/else/.vjenv-root"]),
            Some(("/somewhere/else".into(), RootKind::Marker))
        );
        assert_eq!(
            resolve_at("/somewhere/else", &["/somewhere/else/.VJCROOT"]),
            Some(("/somewhere/else".into(), RootKind::Marker))
        );
    }

    #[test]
    fn the_deepest_marker_wins() {
        assert_eq!(
            resolve_at(
                "/a/outer/inner/src",
                &["/a/outer/.vjenv-root", "/a/outer/inner/.vjenv-root"]
            ),
            Some(("/a/outer/inner".into(), RootKind::Marker))
        );
    }

    #[test]
    fn a_nested_git_repo_does_not_escape_its_declared_project() {
        assert_eq!(
            resolve_at(
                "/h/Projects/app/vendor/lib/src",
                &["/h/Projects/app/vendor/lib/.git", "/h/Projects/app/.git"]
            ),
            Some(("/h/Projects/app".into(), RootKind::Container))
        );
        assert_eq!(
            resolve_at("/h/nixconf/vendor/dep", &["/h/nixconf/vendor/dep/.git"]),
            Some(("/h/nixconf".into(), RootKind::Standalone))
        );
    }

    #[test]
    fn vcs_is_the_fallback_when_nothing_is_declared() {
        assert_eq!(
            resolve_at("/tmp/scratch/repo/src", &["/tmp/scratch/repo/.git"]),
            Some(("/tmp/scratch/repo".into(), RootKind::Vcs))
        );
        assert_eq!(
            resolve_at("/tmp/scratch/repo/src", &["/tmp/scratch/repo/.jj"]),
            Some(("/tmp/scratch/repo".into(), RootKind::Vcs))
        );
        assert_eq!(
            resolve_at("/tmp/a/b/c", &["/tmp/a/.git", "/tmp/a/b/.git"]),
            Some(("/tmp/a/b".into(), RootKind::Vcs))
        );
    }

    #[test]
    fn an_unclaimed_directory_has_no_root() {
        assert_eq!(resolve_at("/tmp/nothing/here", &[]), None);
        assert_eq!(resolve_at("/", &[]), None);
    }

    #[test]
    fn a_marker_beats_a_container_at_the_same_depth() {
        assert_eq!(
            resolve_at("/h/Projects/app", &["/h/Projects/app/.vjenv-root"]),
            Some(("/h/Projects/app".into(), RootKind::Marker))
        );
    }

    #[test]
    fn real_fs_probe_sees_a_real_tree() {
        let tmp = tempfile::tempdir().unwrap();
        let deep = tmp.path().join("proj/a/b");
        std::fs::create_dir_all(&deep).unwrap();
        std::fs::write(tmp.path().join("proj/.vjenv-root"), "").unwrap();

        let roots = Roots {
            markers: vec![".vjenv-root".into()],
            ..Default::default()
        };
        assert_eq!(
            resolve(&deep, &roots, &RealFs),
            Some((tmp.path().join("proj"), RootKind::Marker))
        );
    }
}
