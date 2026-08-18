mod common;

use common::Fixture;
use vjtrees::jj::{Moving, Placement, quote_workspace};
use vjtrees::target::pick_target;

fn build_trunk(fixture: &Fixture) {
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "one", "base one");
    fixture.new_change(&trunk);
    fixture.commit(&trunk, "b.txt", "two", "base two");
    fixture.new_change(&trunk);
}

fn target_of(fixture: &Fixture) -> vjtrees::target::Target {
    let wc = quote_workspace(fixture.root.trunk_workspace());
    let ancestors = fixture
        .jj
        .ancestors(&wc, fixture.root.config.limits.ancestor_scan)
        .expect("ancestors");

    pick_target(&ancestors).expect("a usable target")
}

fn both_shapes() -> Vec<(&'static str, Fixture)> {
    vec![
        ("vjcanvas-shaped", Fixture::vjcanvas_shaped()),
        ("differently-shaped", Fixture::differently_shaped()),
    ]
}

#[test]
fn the_trunk_workspace_is_found_whatever_it_is_called() {
    for (shape, fixture) in both_shapes() {
        let workspaces = fixture.jj.workspaces().expect("workspaces");

        assert!(
            workspaces
                .iter()
                .any(|w| w.name == fixture.root.trunk_workspace()),
            "{shape}: no workspace named {:?} in {workspaces:?}",
            fixture.root.trunk_workspace()
        );
    }
}

#[test]
fn the_target_is_resolved_against_real_jj_for_either_shape() {
    for (shape, fixture) in both_shapes() {
        build_trunk(&fixture);

        let target = target_of(&fixture);

        assert_eq!(target.description, "base two", "{shape}");
        assert_eq!(target.undescribed_above, 1, "{shape}");
        assert_ne!(
            target.insert_before, target.commit_id,
            "{shape}: the insertion point must be the empty change, not the target itself"
        );
    }
}

#[test]
fn resolve_tells_no_match_apart_from_a_broken_query() {
    let fixture = Fixture::vjcanvas_shaped();

    assert!(
        fixture
            .jj
            .resolve("none()")
            .expect("none() is valid")
            .is_none(),
        "a revset that matches nothing must be Ok(None)"
    );

    assert!(
        fixture.jj.resolve("definitely_not_a_function()").is_err(),
        "a broken revset must be an error, not silently empty"
    );
}

#[test]
fn is_ancestor_reports_an_error_instead_of_answering_no() {
    let fixture = Fixture::vjcanvas_shaped();
    build_trunk(&fixture);

    let one = fixture.commit_of("base one");
    let two = fixture.commit_of("base two");

    assert!(fixture.jj.is_ancestor(&one, &two).expect("valid query"));
    assert!(!fixture.jj.is_ancestor(&two, &one).expect("valid query"));

    assert!(
        fixture.jj.is_ancestor("bogus_function()", &two).is_err(),
        "a query jj could not answer must not come back as `false` — \
         that is what let a backwards rebase slip past the guard"
    );
}

#[test]
fn count_ancestors_reports_an_error_instead_of_answering_zero() {
    let fixture = Fixture::vjcanvas_shaped();
    build_trunk(&fixture);

    let two = fixture.commit_of("base two");
    assert!(fixture.jj.count_ancestors(&two).expect("valid query") >= 2);

    assert!(
        fixture.jj.count_ancestors("bogus_function()").is_err(),
        "an unanswerable count must not be reported as v0"
    );
}

#[test]
fn rebasing_a_workspace_subtree_moves_it_onto_the_target() {
    let fixture = Fixture::vjcanvas_shaped();
    build_trunk(&fixture);

    let one = fixture.commit_of("base one");
    fixture.add_workspace("video1", &one);
    fixture.commit("video1", "video/scene.vjc", "scene", "video work");

    let target = target_of(&fixture);
    let moving = fixture.commit_of("video work");

    fixture
        .jj
        .rebase(Moving::Subtree(&moving), Placement::Onto(&target.commit_id))
        .expect("rebase");

    let moved = fixture.commit_of("video work");
    assert_eq!(
        fixture.parents_of(&moved),
        vec![target.commit_id.clone()],
        "the video subtree should now sit directly on the target"
    );
}

#[test]
fn lifting_inserts_below_the_trunk_work_in_progress_and_leaves_siblings_alone() {
    let fixture = Fixture::vjcanvas_shaped();
    build_trunk(&fixture);

    let target = target_of(&fixture);

    fixture.add_workspace("video1", &target.commit_id);
    fixture.commit("video1", "src/shared.ts", "shared", "shared fix");

    fixture.add_workspace("video2", &target.commit_id);
    fixture.commit("video2", "video/other.vjc", "other", "other work");

    let lifted = fixture.commit_of("shared fix");
    let sibling_before = fixture.commit_of("other work");
    assert_eq!(
        fixture.parents_of(&sibling_before),
        vec![target.commit_id.clone()]
    );

    fixture
        .jj
        .rebase(
            Moving::Single(&lifted),
            Placement::Before(&target.insert_before),
        )
        .expect("lift");

    let lifted_now = fixture.commit_of("shared fix");
    assert_eq!(
        fixture.parents_of(&lifted_now),
        vec![target.commit_id.clone()],
        "the lifted change should land directly on the described target"
    );

    let sibling_now = fixture.commit_of("other work");
    assert_eq!(
        fixture.parents_of(&sibling_now),
        vec![target.commit_id.clone()],
        "--insert-before must not drag workspaces already forked off the target; \
         --insert-after would have"
    );
}

#[test]
fn a_rewrite_from_the_root_leaves_other_workspaces_stale_until_refreshed() {
    use vjtrees::jj::WorkingCopy;
    use vjtrees::stale;

    let fixture = Fixture::vjcanvas_shaped();
    build_trunk(&fixture);

    let one = fixture.commit_of("base one");
    fixture.add_workspace("video1", &one);
    fixture.commit("video1", "video/scene.vjc", "scene", "video work");
    fixture.new_change("video1");

    let target = target_of(&fixture);
    let moving = fixture.commit_of("video work");

    fixture
        .jj
        .rebase(Moving::Subtree(&moving), Placement::Onto(&target.commit_id))
        .expect("rebase");

    let dir = fixture.root.workspace_path("video1");
    assert_eq!(
        fixture.jj.working_copy_state(&dir).expect("state"),
        WorkingCopy::Stale,
        "a rewrite issued from the root leaves the workspace holding the old files"
    );

    stale::refresh_all(&fixture.root, &fixture.jj).expect("refresh");

    assert_eq!(
        fixture.jj.working_copy_state(&dir).expect("state"),
        WorkingCopy::Clean,
        "refreshing must bring the files back in line with the history"
    );
}

#[test]
fn a_working_copy_holding_content_reads_as_modified_not_clean() {
    use vjtrees::jj::WorkingCopy;

    let fixture = Fixture::vjcanvas_shaped();
    build_trunk(&fixture);

    let target = target_of(&fixture);
    fixture.add_workspace("video1", &target.commit_id);

    let dir = fixture.root.workspace_path("video1");
    assert_eq!(
        fixture.jj.working_copy_state(&dir).expect("state"),
        WorkingCopy::Clean,
        "a fresh workspace sits on an empty change"
    );

    fixture.commit("video1", "video/scene.vjc", "scene", "video work");

    assert_eq!(
        fixture.jj.working_copy_state(&dir).expect("state"),
        WorkingCopy::Modified,
        "jj has no staging area — content in @ is what `jj diff` reports, \
         so `modified` means the working-copy change is non-empty"
    );
}

#[test]
fn the_scan_limit_comes_from_the_config() {
    let fixture = Fixture::differently_shaped();
    assert_eq!(fixture.root.config.limits.ancestor_scan, 25);

    let trunk = fixture.root.trunk_workspace().to_string();
    fixture.commit(&trunk, "a.txt", "one", "base one");
    fixture.new_change(&trunk);

    let wc = quote_workspace(&trunk);
    let ancestors = fixture.jj.ancestors(&wc, 1).expect("ancestors");

    assert_eq!(
        ancestors.len(),
        1,
        "the limit must actually be passed to jj"
    );
}
