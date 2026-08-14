mod common;

use anyhow::bail;
use common::{Fixture, vjcanvas_shaped_backing_up_to, vjcanvas_shaped_requiring};
use std::cell::Cell;
use std::fs;
use std::sync::{Mutex, MutexGuard};
use vjtrees::config::Require;
use vjtrees::guard::{
    Mutation, Reversibility, backup_required, detect_race, divergent_ids, guarded,
};
use vjtrees::jj::WorkingCopy;
use vjtrees::ui;

fn isolated() -> MutexGuard<'static, ()> {
    static SERIAL: Mutex<()> = Mutex::new(());

    let held = SERIAL
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());

    ui::assume_yes(true);

    held
}

const UNUSABLE_REPOSITORY: &str = "/vjtrees/no/such/repository";

fn backing_up_to_somewhere_unusable(require: &str) -> String {
    vjcanvas_shaped_backing_up_to(require, UNUSABLE_REPOSITORY)
}

fn reversible(command: &str) -> Mutation {
    Mutation::new(command, &format!("Test mutation {command}"))
}

fn trunk_with_two_changes() -> Fixture {
    let fixture = Fixture::vjcanvas_shaped();
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "one", "base one");
    fixture.new_change(&trunk);
    fixture.commit(&trunk, "b.txt", "two", "base two");

    fixture
}

#[test]
fn the_lock_is_held_for_the_whole_body_and_released_afterwards() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();
    let lock_path = fixture.root.lock_path();

    assert!(!lock_path.exists(), "nothing holds the lock yet");

    guarded(&fixture.root, &fixture.jj, reversible("rebase"), |_| {
        assert!(
            lock_path.exists(),
            "the body must run while the project is locked"
        );
        let holder = fs::read_to_string(&lock_path).expect("read lock");
        assert!(
            holder.contains("rebase"),
            "the lock must name the command holding it, got: {holder}"
        );
        Ok(())
    })
    .expect("a clean reversible mutation must succeed");

    assert!(!lock_path.exists(), "the lock must not outlive the command");
}

#[test]
fn a_failing_body_propagates_its_error_and_still_releases_the_lock() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();
    let lock_path = fixture.root.lock_path();

    let error = guarded(&fixture.root, &fixture.jj, reversible("rebase"), |_| {
        bail!("the body blew up");
        #[allow(unreachable_code)]
        Ok(())
    })
    .expect_err("the body's error must reach the caller");

    assert!(
        format!("{error:#}").contains("the body blew up"),
        "got: {error:#}"
    );
    assert!(
        !lock_path.exists(),
        "a failed mutation must not leave the project locked"
    );
}

#[test]
fn the_operation_id_it_reports_really_restores_the_repository() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();
    let before = fixture.descriptions();

    let reported = guarded(
        &fixture.root,
        &fixture.jj,
        reversible("rebase"),
        |recovery| {
            fixture.jj.describe("@", "rewritten by the mutation")?;
            Ok(recovery.op_id.clone())
        },
    )
    .expect("guarded mutation");

    assert!(
        fixture
            .descriptions()
            .contains(&"rewritten by the mutation".to_string()),
        "the mutation must actually have changed history"
    );

    fixture
        .jj
        .op_restore(&reported)
        .expect("the reported operation id must be restorable");

    assert_eq!(
        fixture.descriptions(),
        before,
        "the operation vjtrees prints must undo exactly what the mutation did"
    );
}

#[test]
fn a_divergent_repository_refuses_an_ordinary_mutation() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();
    fixture.diverge("one of two rewrites");

    let ran = Cell::new(false);
    let error = guarded(&fixture.root, &fixture.jj, reversible("rebase"), |_| {
        ran.set(true);
        Ok(())
    })
    .expect_err("divergence must stop history rewriting");

    assert!(!ran.get(), "the body must never run on a divergent repo");

    let message = format!("{error:#}");
    assert!(message.contains("divergent"), "got: {message}");
    assert!(
        message.contains("vjtrees repair"),
        "the refusal must say how to fix it, got: {message}"
    );
}

#[test]
fn repair_is_the_one_mutation_allowed_to_run_on_a_divergent_repository() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();
    fixture.diverge("one of two rewrites");

    let ran = Cell::new(false);
    guarded(
        &fixture.root,
        &fixture.jj,
        Mutation::new("repair", "Resolve divergence").allowing_divergent(),
        |_| {
            ran.set(true);
            Ok(())
        },
    )
    .expect("repair is what clears divergence, so it must be allowed through");

    assert!(ran.get(), "repair's body must run");
}

#[test]
fn a_stale_workspace_is_refreshed_before_the_body_runs() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();
    fixture.add_workspace("feature", &fixture.commit_of("base one"));
    fixture.make_stale("feature", &fixture.commit_of("base two"));

    let feature_dir = fixture.dir_of("feature");

    guarded(&fixture.root, &fixture.jj, reversible("rebase"), |_| {
        assert_eq!(
            fixture.jj.working_copy_state(&feature_dir).ok(),
            Some(WorkingCopy::Clean),
            "the guard must refresh every workspace before the body touches history"
        );
        Ok(())
    })
    .expect("guarded mutation");

    assert_eq!(
        fixture.jj.working_copy_state(&feature_dir).ok(),
        Some(WorkingCopy::Clean),
        "and again afterwards, so the editor opens on the new history"
    );
}

#[test]
fn the_backup_policy_matrix_matches_the_documented_rule() {
    assert!(!backup_required(
        Require::Never,
        Reversibility::Irreversible
    ));
    assert!(!backup_required(Require::Never, Reversibility::JjOp));

    assert!(backup_required(Require::Always, Reversibility::JjOp));
    assert!(backup_required(
        Require::Always,
        Reversibility::Irreversible
    ));

    assert!(backup_required(
        Require::Irreversible,
        Reversibility::Irreversible
    ));
    assert!(!backup_required(Require::Irreversible, Reversibility::JjOp));
}

#[test]
fn an_irreversible_mutation_will_not_run_without_a_backup() {
    let _serial = isolated();
    let fixture = Fixture::new(&vjcanvas_shaped_requiring("irreversible"));
    let trunk = fixture.root.trunk_workspace().to_string();
    fixture.commit(&trunk, "a.txt", "one", "base one");

    let ran = Cell::new(false);
    let error = guarded(
        &fixture.root,
        &fixture.jj,
        Mutation::new("delete", "Delete workspace feature").irreversible("feature"),
        |_| {
            ran.set(true);
            Ok(())
        },
    )
    .expect_err("deleting without a backup must be refused");

    assert!(
        !ran.get(),
        "the refusal must happen before anything is destroyed"
    );

    let message = format!("{error:#}");
    assert!(
        message.contains("no backup is configured"),
        "got: {message}"
    );
    assert!(
        message.contains("[backup] repository"),
        "the refusal must say how to fix it, got: {message}"
    );
}

#[test]
fn a_reversible_mutation_only_warns_when_no_backup_is_configured() {
    let _serial = isolated();
    let fixture = Fixture::new(&vjcanvas_shaped_requiring("irreversible"));
    let trunk = fixture.root.trunk_workspace().to_string();
    fixture.commit(&trunk, "a.txt", "one", "base one");

    let ran = Cell::new(false);
    guarded(&fixture.root, &fixture.jj, reversible("rebase"), |_| {
        ran.set(true);
        Ok(())
    })
    .expect("jj op restore can undo a rebase, so a missing backup must only warn");

    assert!(ran.get(), "the body must still run");
}

#[test]
fn a_policy_of_always_blocks_even_reversible_work_without_a_backup() {
    let _serial = isolated();
    let fixture = Fixture::new(&vjcanvas_shaped_requiring("always"));
    let trunk = fixture.root.trunk_workspace().to_string();
    fixture.commit(&trunk, "a.txt", "one", "base one");

    let ran = Cell::new(false);
    let error = guarded(&fixture.root, &fixture.jj, reversible("rebase"), |_| {
        ran.set(true);
        Ok(())
    })
    .expect_err("a policy of always must be honoured for every mutation");

    assert!(!ran.get(), "the body must not run");
    assert!(
        format!("{error:#}").contains("no backup is configured"),
        "got: {error:#}"
    );
}

#[test]
fn a_backup_that_fails_blocks_the_work_that_required_it() {
    let _serial = isolated();
    let fixture = Fixture::new(&backing_up_to_somewhere_unusable("always"));
    let trunk = fixture.root.trunk_workspace().to_string();
    fixture.commit(&trunk, "a.txt", "one", "base one");

    let ran = Cell::new(false);
    let error = guarded(&fixture.root, &fixture.jj, reversible("rebase"), |_| {
        ran.set(true);
        Ok(())
    })
    .expect_err("a configured backup that fails is not a backup");

    assert!(!ran.get(), "the body must not run");
    assert!(
        format!("{error:#}").contains("refusing to continue without a backup"),
        "got: {error:#}"
    );
}

#[test]
fn a_backup_that_fails_does_not_block_work_that_never_needed_one() {
    let _serial = isolated();
    let fixture = Fixture::new(&backing_up_to_somewhere_unusable("never"));
    let trunk = fixture.root.trunk_workspace().to_string();
    fixture.commit(&trunk, "a.txt", "one", "base one");

    let ran = Cell::new(false);
    guarded(&fixture.root, &fixture.jj, reversible("rebase"), |_| {
        ran.set(true);
        Ok(())
    })
    .expect("a failed backup under require=never must only ask, not refuse");

    assert!(ran.get(), "the body must run once the failure is accepted");
}

#[test]
fn a_commit_that_became_divergent_during_the_command_is_detected() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();

    let before_divergent = divergent_ids(&fixture.jj).expect("divergent ids");
    let op_before = fixture.jj.op_head().expect("op head");

    fixture.diverge("something else rewrote this");

    let race = detect_race(&fixture.jj, &op_before, &before_divergent);

    assert!(race.happened(), "a concurrent rewrite must be noticed");
    assert!(
        !race.new_divergent.is_empty(),
        "the newly divergent commits must be named so they can be repaired"
    );
    assert!(
        !race.reconciles.is_empty(),
        "jj's own reconcile operation must be spotted in the op log"
    );
}

#[test]
fn divergence_that_was_already_there_is_not_blamed_on_this_command() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();
    fixture.diverge("divergence from before the command");

    let before_divergent = divergent_ids(&fixture.jj).expect("divergent ids");
    let op_before = fixture.jj.op_head().expect("op head");

    let race = detect_race(&fixture.jj, &op_before, &before_divergent);

    assert!(
        !race.happened(),
        "pre-existing divergence is repair's problem, not a race this command caused"
    );
}

#[test]
fn a_quiet_repository_reports_no_race() {
    let _serial = isolated();
    let fixture = trunk_with_two_changes();

    let before_divergent = divergent_ids(&fixture.jj).expect("divergent ids");
    let op_before = fixture.jj.op_head().expect("op head");

    let race = detect_race(&fixture.jj, &op_before, &before_divergent);

    assert!(!race.happened(), "nothing else ran, so nothing to report");
}
