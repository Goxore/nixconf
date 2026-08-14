use vjtrees::jj::Change;
use vjtrees::paths::{Category, breaks_dependents, categorize, is_owned};
use vjtrees::target::{NoTarget, pick_target};

fn change(commit: &str, description: &str) -> Change {
    Change {
        commit_id: commit.to_string(),
        change_id: format!("c{commit}"),
        divergent: false,
        described: !description.is_empty(),
        description: description.to_string(),
    }
}

fn divergent(commit: &str, description: &str) -> Change {
    Change {
        divergent: true,
        ..change(commit, description)
    }
}

#[test]
fn the_target_is_the_newest_described_change_with_an_empty_one_above_it() {
    let ancestors = vec![
        change("04", ""),
        change("03", "base three"),
        change("02", "base two"),
        change("01", "base one"),
    ];

    let target = pick_target(&ancestors).expect("a target");

    assert_eq!(target.commit_id, "03");
    assert_eq!(target.description, "base three");
    assert_eq!(target.undescribed_above, 1);
}

#[test]
fn the_insertion_point_is_the_oldest_undescribed_change_above_the_target() {
    let ancestors = vec![
        change("06", ""),
        change("05", ""),
        change("04", ""),
        change("03", "base three"),
    ];

    let target = pick_target(&ancestors).expect("a target");

    assert_eq!(target.undescribed_above, 3);
    assert_eq!(
        target.insert_before, "04",
        "lifting must splice in below the trunk's work in progress, not above it"
    );
}

#[test]
fn a_described_tip_with_nothing_above_it_is_refused() {
    let ancestors = vec![change("03", "still editing this"), change("02", "base two")];

    match pick_target(&ancestors) {
        Err(NoTarget::NoEmptyAbove { tip }) => assert_eq!(tip.commit_id, "03"),
        other => panic!("expected NoEmptyAbove, got {other:?}"),
    }
}

#[test]
fn a_line_with_no_described_change_is_refused() {
    let ancestors = vec![change("02", ""), change("01", "")];

    assert!(matches!(
        pick_target(&ancestors),
        Err(NoTarget::NoDescribed)
    ));
}

#[test]
fn an_empty_log_is_refused() {
    assert!(matches!(pick_target(&[]), Err(NoTarget::EmptyLog)));
}

#[test]
fn a_divergent_change_in_the_line_is_refused_rather_than_guessed_past() {
    let ancestors = vec![
        change("04", ""),
        divergent("03", "which one is this?"),
        change("02", "base two"),
    ];

    match pick_target(&ancestors) {
        Err(NoTarget::Divergent { change }) => assert_eq!(change.commit_id, "03"),
        other => panic!("expected Divergent, got {other:?}"),
    }
}

#[test]
fn a_divergent_change_is_caught_even_when_a_valid_target_sits_below_it() {
    let ancestors = vec![
        divergent("05", ""),
        change("04", ""),
        change("03", "a perfectly good target"),
    ];

    assert!(
        matches!(pick_target(&ancestors), Err(NoTarget::Divergent { .. })),
        "a divergent ancestor makes the whole line untrustworthy"
    );
}

#[test]
fn owned_patterns_match_directories_by_prefix_and_files_exactly() {
    let owned = vec!["video/".to_string(), "notes.md".to_string()];

    assert!(is_owned("video/scene.vjc", &owned));
    assert!(is_owned("video", &owned));
    assert!(is_owned("notes.md", &owned));
    assert!(!is_owned("videos/other.vjc", &owned));
    assert!(!is_owned("notes.md.bak", &owned));
    assert!(!is_owned("src/dsl.ts", &owned));
}

#[test]
fn everything_that_is_not_owned_counts_as_shared() {
    let owned = vec!["video/".to_string()];

    assert_eq!(
        categorize(&["src/new-thing.ts".to_string()], &owned),
        Category::Shared,
        "a directory added next month must classify correctly the day it appears"
    );
}

#[test]
fn a_change_touching_both_sides_is_mixed() {
    let owned = vec!["video/".to_string()];
    let files = vec!["video/scene.vjc".to_string(), "src/dsl.ts".to_string()];

    assert_eq!(categorize(&files, &owned), Category::Mixed);
}

#[test]
fn an_empty_change_is_not_shared_work_to_lift() {
    assert_eq!(categorize(&[], &["video/".to_string()]), Category::Owned);
}

#[test]
fn fragile_paths_are_matched_the_same_way() {
    let fragile = vec!["src/dsl/".to_string(), "package.json".to_string()];

    assert!(breaks_dependents("src/dsl/parser.ts", &fragile));
    assert!(breaks_dependents("package.json", &fragile));
    assert!(!breaks_dependents("src/other.ts", &fragile));
    assert!(!breaks_dependents("package.json.bak", &fragile));
}
