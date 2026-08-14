mod common;

use common::Fixture;
use vjtrees::jj::{Moving, Placement, WorkingCopy};

fn trunk_with_a_workspace() -> (Fixture, std::path::PathBuf) {
    let fixture = Fixture::vjcanvas_shaped();
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "one", "base one");
    let one = fixture.commit_of("base one");
    fixture.new_change(&trunk);
    fixture.commit(&trunk, "b.txt", "two", "base two");

    fixture.add_workspace("feature", &one);

    let dir = fixture.dir_of("feature");
    (fixture, dir)
}

fn stale_destination(fixture: &Fixture) -> String {
    fixture.commit_of("base two")
}

#[test]
fn a_clean_workspace_is_clean_and_a_written_file_makes_it_modified() {
    let (fixture, dir) = trunk_with_a_workspace();

    assert_eq!(
        fixture.jj.working_copy_state(&dir).expect("read state"),
        WorkingCopy::Clean
    );

    std::fs::write(dir.join("scratch.txt"), "work in progress").expect("write");

    assert_eq!(
        fixture.jj.working_copy_state(&dir).expect("read state"),
        WorkingCopy::Modified,
        "modified means the working-copy change is non-empty"
    );
}

#[test]
fn a_stale_workspace_is_recognised_from_jjs_own_wording() {
    let (fixture, dir) = trunk_with_a_workspace();

    fixture.make_stale("feature", &stale_destination(&fixture));

    assert_eq!(
        fixture.jj.working_copy_state(&dir).expect("read state"),
        WorkingCopy::Stale,
        "staleness is read out of jj's stderr — a reworded message would silently \
         turn every refresh into a no-op"
    );
}

#[test]
fn update_stale_reports_whether_it_actually_moved_anything() {
    let (fixture, dir) = trunk_with_a_workspace();

    fixture.make_stale("feature", &stale_destination(&fixture));

    assert!(
        fixture
            .jj
            .update_stale(&dir)
            .expect("update a stale workspace"),
        "a stale workspace must report that it was updated"
    );
    assert!(
        !fixture
            .jj
            .update_stale(&dir)
            .expect("update a healthy workspace"),
        "a healthy workspace must report that there was nothing to do — \
         this is read from jj saying \"not stale\""
    );
}

#[test]
fn a_rebase_that_collides_is_reported_as_conflicted() {
    let fixture = Fixture::vjcanvas_shaped();
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "the original line", "base");
    let base = fixture.commit_of("base");

    fixture.new_change(&trunk);
    fixture.commit(&trunk, "a.txt", "rewritten one way", "side x");
    let x = fixture.commit_of("side x");

    fixture.jj.new_change(Some(&base)).expect("fork from base");
    fixture.commit(&trunk, "a.txt", "rewritten another way", "side y");
    let y = fixture.commit_of("side y");

    let outcome = fixture
        .jj
        .rebase(Moving::Subtree(&y), Placement::Onto(&x))
        .expect("jj reports conflicts through its exit status, not an error");

    assert!(
        outcome.conflicted,
        "two changes rewriting the same line must be reported as a conflict — \
         vjtrees reads this from jj's stderr, so a reworded message would let \
         a conflicted rebase be announced as a clean one"
    );
}

#[test]
fn a_rebase_that_does_not_collide_is_not_reported_as_conflicted() {
    let fixture = Fixture::vjcanvas_shaped();
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "shared", "base");
    let base = fixture.commit_of("base");

    fixture.new_change(&trunk);
    fixture.commit(&trunk, "x.txt", "only x", "side x");
    let x = fixture.commit_of("side x");

    fixture.jj.new_change(Some(&base)).expect("fork from base");
    fixture.commit(&trunk, "y.txt", "only y", "side y");
    let y = fixture.commit_of("side y");

    let outcome = fixture
        .jj
        .rebase(Moving::Subtree(&y), Placement::Onto(&x))
        .expect("rebase");

    assert!(
        !outcome.conflicted,
        "changes to different files must not be mistaken for a conflict"
    );
}
