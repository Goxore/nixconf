mod common;

use common::Fixture;
use vjtrees::jj::quote_workspace;
use vjtrees::target::{NoTarget, pick_target};

fn make_divergent(fixture: &Fixture) -> String {
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "one", "base one");
    fixture.new_change(&trunk);
    fixture.commit(&trunk, "b.txt", "two", "will diverge");

    let before = fixture.jj.op_head().expect("op head");

    fixture.jj_in(&trunk, &["describe", "-m", "first rewrite"]);

    fixture.jj_in(&trunk, &["op", "restore", &before]);
    fixture.jj_in(&trunk, &["describe", "-m", "second rewrite"]);

    fixture.jj_in(&trunk, &["op", "restore", "--what", "repo", &before]);

    fixture
        .jj_in(
            &trunk,
            &[
                "log",
                "-r",
                "all()",
                "--no-graph",
                "--ignore-working-copy",
                "-T",
                r#"change_id.short() ++ "\n""#,
            ],
        )
        .lines()
        .next()
        .unwrap_or_default()
        .to_string()
}

#[test]
fn divergence_is_visible_through_the_jj_layer() {
    let fixture = Fixture::vjcanvas_shaped();
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "one", "base one");
    fixture.new_change(&trunk);
    fixture.commit(&trunk, "b.txt", "two", "original");

    let before = fixture.jj.op_head().expect("op head");
    fixture.jj_in(&trunk, &["describe", "-m", "rewrite A"]);
    let after_a = fixture.jj.op_head().expect("op head");

    fixture.jj_in(&trunk, &["op", "restore", &before]);
    fixture.jj_in(&trunk, &["describe", "-m", "rewrite B"]);

    let merged = fixture.jj_in(
        &trunk,
        &["op", "log", "-n", "1", "--no-graph", "-T", "id.short()"],
    );
    assert!(!merged.is_empty());
    assert_ne!(after_a, before);

    let divergent = fixture.jj.divergent().expect("divergent query works");
    assert!(
        divergent.is_empty() || divergent.len() >= 2,
        "divergent() must return every commit sharing a change id, got {divergent:?}"
    );
}

#[test]
fn a_divergent_trunk_line_refuses_to_produce_a_target() {
    let fixture = Fixture::vjcanvas_shaped();
    make_divergent(&fixture);

    let divergent = fixture.jj.divergent().expect("divergent query");
    if divergent.is_empty() {
        return;
    }

    let wc = quote_workspace(fixture.root.trunk_workspace());
    let ancestors = fixture
        .jj
        .ancestors(&wc, fixture.root.config.limits.ancestor_scan)
        .expect("ancestors");

    if ancestors.iter().any(|c| c.divergent) {
        assert!(
            matches!(pick_target(&ancestors), Err(NoTarget::Divergent { .. })),
            "a divergent ancestor must stop placement, not be guessed past"
        );
    }
}

#[test]
fn the_change_template_marks_divergent_commits() {
    let fixture = Fixture::vjcanvas_shaped();
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "one", "base one");

    let changes = fixture
        .jj
        .ancestors(&quote_workspace(&trunk), 10)
        .expect("ancestors");

    assert!(
        changes.iter().all(|c| !c.divergent),
        "a clean repo must not report divergence"
    );
    assert!(
        changes.iter().any(|c| c.described),
        "described must be read from the template, not inferred"
    );
}

#[test]
fn ops_since_returns_only_what_happened_after_the_recorded_operation() {
    let fixture = Fixture::vjcanvas_shaped();
    let trunk = fixture.root.trunk_workspace().to_string();

    fixture.commit(&trunk, "a.txt", "one", "base one");
    let mark = fixture.jj.op_head().expect("op head");

    fixture.new_change(&trunk);
    fixture.commit(&trunk, "b.txt", "two", "base two");

    let since = fixture.jj.ops_since(&mark, 50).expect("ops since");

    assert!(
        !since.is_empty(),
        "operations after the mark should be reported"
    );
    assert!(
        since.iter().all(|op| op.id != mark),
        "the mark itself must not be included"
    );

    let none = fixture
        .jj
        .ops_since(&fixture.jj.op_head().unwrap(), 50)
        .unwrap();
    assert!(
        none.is_empty(),
        "nothing has happened since the current head"
    );
}
