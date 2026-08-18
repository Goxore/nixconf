mod common;

use common::{Fixture, require_borg, vjcanvas_shaped_backing_up_to};
use std::fs;
use tempfile::TempDir;
use vjtrees::backup;

fn backed_up_project() -> (Fixture, TempDir) {
    require_borg();

    let repository = TempDir::new().expect("tempdir");
    let path = repository.path().join("repo");
    let config = vjcanvas_shaped_backing_up_to("never", &path.to_string_lossy());
    let fixture = Fixture::new(&config);

    let trunk = fixture.root.trunk_workspace().to_string();
    fixture.commit(&trunk, "keep-me.txt", "precious", "a change worth keeping");

    (fixture, repository)
}

#[test]
fn a_repository_is_created_on_first_backup_without_any_init_step() {
    let (fixture, repository) = backed_up_project();
    let path = repository.path().join("repo");

    assert!(
        !path.exists(),
        "the fixture must start without a repository, or this proves nothing"
    );

    backup::run_backup(&fixture.root, &fixture.root.config.backup).expect("first backup");

    assert!(
        path.join("config").is_file(),
        "borg init must have run implicitly"
    );
}

#[test]
fn a_backup_reports_the_archive_name_that_borg_actually_created() {
    let (fixture, _repository) = backed_up_project();

    let snapshot = backup::run_backup(&fixture.root, &fixture.root.config.backup).expect("backup");

    assert!(
        snapshot.id.starts_with("vjtrees-"),
        "the reported name must be the real archive name, got {:?}",
        snapshot.id
    );
    assert_ne!(
        snapshot.id, "unknown",
        "parsing borg's --json output must not silently fall back"
    );

    let listed = backup::archives(&fixture.root.config.backup).expect("list archives");
    assert!(
        listed.iter().any(|a| a.name == snapshot.id),
        "the reported snapshot must be findable again, got {listed:?}"
    );
}

#[test]
fn listing_a_repository_that_does_not_exist_yet_is_empty_rather_than_an_error() {
    let (fixture, _repository) = backed_up_project();

    let listed = backup::archives(&fixture.root.config.backup)
        .expect("listing before the first backup must not fail");

    assert!(listed.is_empty(), "got {listed:?}");
}

#[test]
fn restore_brings_a_backed_up_file_back_without_touching_the_working_copy() {
    let (fixture, _repository) = backed_up_project();
    let config = &fixture.root.config.backup;

    let snapshot = backup::run_backup(&fixture.root, config).expect("backup");

    let trunk = fixture.root.trunk_workspace().to_string();
    let live = fixture.dir_of(&trunk).join("keep-me.txt");
    fs::write(&live, "clobbered").expect("overwrite the live file");

    let destination = TempDir::new().expect("tempdir");
    let into = destination.path().join("restored");
    backup::restore(config, &snapshot.id, &into, &[]).expect("restore");

    let recovered = find_file(&into, "keep-me.txt").expect("the restored tree must contain it");
    assert_eq!(
        fs::read_to_string(&recovered).expect("read restored"),
        "precious"
    );

    assert_eq!(
        fs::read_to_string(&live).expect("read live"),
        "clobbered",
        "restore must never write over the working copy"
    );
}

#[test]
fn restore_refuses_a_destination_that_already_has_something_in_it() {
    let (fixture, _repository) = backed_up_project();
    let config = &fixture.root.config.backup;

    let snapshot = backup::run_backup(&fixture.root, config).expect("backup");

    let destination = TempDir::new().expect("tempdir");
    let into = destination.path().join("restored");
    fs::create_dir_all(&into).expect("create destination");
    fs::write(into.join("someones-work.txt"), "do not lose me").expect("write");

    let error = backup::restore(config, &snapshot.id, &into, &[])
        .expect_err("a non-empty destination must be refused");

    assert!(format!("{error:#}").contains("not empty"), "got: {error:#}");
    assert_eq!(
        fs::read_to_string(into.join("someones-work.txt")).expect("read"),
        "do not lose me"
    );
}

#[test]
fn forget_keeps_the_most_recent_snapshot() {
    let (fixture, _repository) = backed_up_project();
    let mut config = fixture.root.config.backup.clone();
    config.keep_last = 1;
    config.keep_daily = 0;

    backup::run_backup(&fixture.root, &config).expect("first backup");
    let second = backup::run_backup(&fixture.root, &config).expect("second backup");

    backup::forget(&config).expect("forget");

    let remaining = backup::archives(&config).expect("list archives");
    assert!(
        remaining.iter().any(|a| a.name == second.id),
        "the newest snapshot must survive, got {remaining:?}"
    );
}

#[test]
fn a_stale_lock_is_reported_with_the_command_that_clears_it() {
    assert!(backup::is_lock_failure(
        "Failed to create/acquire the lock /tmp/repo/lock.exclusive"
    ));
    assert!(!backup::is_lock_failure("Repository does not exist"));
}

fn find_file(dir: &std::path::Path, name: &str) -> Option<std::path::PathBuf> {
    for entry in fs::read_dir(dir).ok()? {
        let path = entry.ok()?.path();
        if path.is_dir() {
            if let Some(found) = find_file(&path, name) {
                return Some(found);
            }
        } else if path.file_name()?.to_string_lossy() == name {
            return Some(path);
        }
    }
    None
}
