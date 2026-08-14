use std::fs;
use tempfile::TempDir;
use vjtrees::lock::Lock;

const ANOTHER_LIVE_PROCESS: u32 = 1;

fn holder_file(path: &std::path::Path, pid: u32, command: &str) {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).unwrap();
    }
    fs::write(
        path,
        format!("pid = {pid}\ncommand = \"{command}\"\nstarted_at = 1\n"),
    )
    .unwrap();
}

#[test]
fn a_lock_held_by_another_live_process_is_refused_and_names_it() {
    let dir = TempDir::new().expect("tempdir");
    let path = dir.path().join("state").join("lock");

    holder_file(&path, ANOTHER_LIVE_PROCESS, "rebase");

    let error = Lock::acquire(&path, "lift").expect_err("must refuse");
    let message = format!("{error:#}");

    assert!(message.contains("rebase"), "got: {message}");
    assert!(message.contains("pid 1"), "got: {message}");
    assert!(
        message.contains("divergent"),
        "the message should say why this matters, got: {message}"
    );
}

#[test]
fn a_lock_held_by_a_dead_process_is_taken_over() {
    let dir = TempDir::new().expect("tempdir");
    let path = dir.path().join("lock");

    holder_file(&path, u32::MAX - 5, "rebase");

    let _taken = Lock::acquire(&path, "lift").expect("a stale lock must not wedge the tool");
}

#[test]
fn the_lock_is_released_when_it_goes_out_of_scope() {
    let dir = TempDir::new().expect("tempdir");
    let path = dir.path().join("lock");

    {
        let _held = Lock::acquire(&path, "rebase").expect("acquire");
        assert!(path.exists());
    }

    assert!(!path.exists(), "the lock file must not outlive the guard");
    Lock::acquire(&path, "lift").expect("the lock is free again");
}

#[test]
fn the_lock_is_released_even_when_the_work_panics() {
    let dir = TempDir::new().expect("tempdir");
    let path = dir.path().join("lock");
    let taken = path.clone();

    let result = std::panic::catch_unwind(move || {
        let _held = Lock::acquire(&taken, "rebase").expect("acquire");
        panic!("the body blew up");
    });

    assert!(result.is_err());
    assert!(
        !path.exists(),
        "a panic must not leave the project permanently locked"
    );
}

#[test]
fn a_command_can_hold_the_lock_across_its_own_nested_mutations() {
    let dir = TempDir::new().expect("tempdir");
    let path = dir.path().join("lock");

    let mut outer = Lock::acquire(&path, "rebase").expect("outer acquire");

    {
        let _inner = Lock::acquire(&path, "rebase").expect(
            "a command already holding the lock must be able to enter guarded work \
             without deadlocking against itself",
        );
        assert!(path.exists());
    }

    assert!(
        path.exists(),
        "releasing the inner guard must not drop the outer command's lock"
    );

    outer.release();
    assert!(!path.exists(), "the outermost release frees the project");
}
