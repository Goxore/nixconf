use anyhow::{Context, Result};
use std::ffi::OsString;
use std::fs;
use std::io::Write;
use std::os::unix::fs::OpenOptionsExt;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};

static STAGED: AtomicU64 = AtomicU64::new(0);

pub fn write(path: &Path, contents: &[u8]) -> Result<()> {
    replace(path, contents, 0o666)
}

pub fn write_private(path: &Path, contents: &[u8]) -> Result<()> {
    replace(path, contents, 0o600)
}

fn replace(path: &Path, contents: &[u8], mode: u32) -> Result<()> {
    let parent = path.parent().unwrap_or(Path::new("."));
    fs::create_dir_all(parent).with_context(|| format!("cannot create {}", parent.display()))?;

    let mut name = OsString::from(".");
    name.push(path.file_name().unwrap_or_default());
    name.push(format!(
        ".tmp.{}.{}",
        std::process::id(),
        STAGED.fetch_add(1, Ordering::Relaxed)
    ));
    let tmp = parent.join(name);

    let staged = || -> std::io::Result<()> {
        let _ = fs::remove_file(&tmp);
        let mut f = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(mode)
            .open(&tmp)?;
        f.write_all(contents)?;
        f.sync_all()
    };
    if let Err(e) = staged() {
        let _ = fs::remove_file(&tmp);
        return Err(anyhow::Error::from(e).context(format!("cannot write {}", path.display())));
    }
    if let Err(e) = fs::rename(&tmp, path) {
        let _ = fs::remove_file(&tmp);
        return Err(anyhow::Error::from(e).context(format!("cannot replace {}", path.display())));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replaces_the_target_and_leaves_no_temporary_behind() {
        let tmp = tempfile::tempdir().unwrap();
        let target = tmp.path().join("nested/state");

        write(&target, b"first").unwrap();
        write(&target, b"second").unwrap();
        assert_eq!(fs::read_to_string(&target).unwrap(), "second");

        let leftovers: Vec<_> = fs::read_dir(target.parent().unwrap())
            .unwrap()
            .map(|e| e.unwrap().file_name())
            .filter(|n| n.to_string_lossy().contains(".tmp."))
            .collect();
        assert!(
            leftovers.is_empty(),
            "temp files left behind: {leftovers:?}"
        );
    }

    #[test]
    fn a_reader_never_observes_a_half_written_file() {
        let tmp = tempfile::tempdir().unwrap();
        let target = tmp.path().join("state");
        let big = "b".repeat(64 * 1024);
        write(&target, b"a").unwrap();

        std::thread::scope(|s| {
            s.spawn(|| {
                for _ in 0..50 {
                    write(&target, big.as_bytes()).unwrap();
                    write(&target, b"a").unwrap();
                }
            });
            s.spawn(|| {
                for _ in 0..200 {
                    let seen = fs::read_to_string(&target).unwrap_or_default();
                    assert!(
                        seen.is_empty() || seen == "a" || seen == big,
                        "torn read of {} bytes",
                        seen.len()
                    );
                }
            });
        });
    }

    #[test]
    fn a_private_file_is_never_readable_by_others() {
        use std::os::unix::fs::PermissionsExt;
        let tmp = tempfile::tempdir().unwrap();
        let target = tmp.path().join("secret");

        write_private(&target, b"key").unwrap();
        let mode = fs::metadata(&target).unwrap().permissions().mode();
        assert_eq!(mode & 0o777, 0o600);
    }

    #[test]
    fn threads_writing_the_same_file_do_not_trip_over_each_other() {
        let tmp = tempfile::tempdir().unwrap();
        let target = tmp.path().join("state");

        std::thread::scope(|s| {
            for _ in 0..8 {
                s.spawn(|| {
                    for _ in 0..50 {
                        write(&target, b"same").unwrap();
                    }
                });
            }
        });
        assert_eq!(fs::read_to_string(&target).unwrap(), "same");
    }

    #[test]
    fn a_failed_write_leaves_the_previous_contents_intact() {
        let tmp = tempfile::tempdir().unwrap();
        let target = tmp.path().join("state");
        write(&target, b"good").unwrap();

        let blocked = target.join("cannot/exist");
        assert!(write(&blocked, b"bad").is_err());
        assert_eq!(fs::read_to_string(&target).unwrap(), "good");
    }
}
