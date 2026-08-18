use vjproj::slots::{
    HOME_SLOT, NUM_PROJECTS, STICKY_TAGS, TOTAL_TAGS, VISIBLE_SLOTS, VISIBLE_TAGS, is_slot,
    is_sticky, real_tag,
};
use vjproj::state::State;

#[test]
fn the_key_row_ascends_in_every_project() {
    for project in 1..=NUM_PROJECTS {
        let row: Vec<u8> = (1..=VISIBLE_TAGS)
            .map(|v| real_tag(project, v).unwrap())
            .collect();
        for pair in row.windows(2) {
            assert!(
                pair[0] < pair[1],
                "project {project} row {row:?} goes backwards at {pair:?}"
            );
        }
    }
}

#[test]
fn the_layout_is_the_one_we_designed() {
    assert_eq!(real_tag(1, 1).unwrap(), 1, "workspace 1 is the project itself");
    assert_eq!(real_tag(5, 1).unwrap(), 5);
    assert_eq!(real_tag(1, 2).unwrap(), 6, "sticky ignores the project");
    assert_eq!(real_tag(5, 2).unwrap(), 6);
    assert_eq!(real_tag(1, 3).unwrap(), 7);
    assert_eq!(real_tag(5, 3).unwrap(), 7);
    assert_eq!(real_tag(3, 9).unwrap(), 13);
}

#[test]
fn only_workspace_one_follows_the_project() {
    for visible in 2..=VISIBLE_TAGS {
        assert!(
            is_sticky(visible),
            "workspace {visible} should be shared across projects"
        );
    }
}

#[test]
fn total_tags_still_matches_tag_num_in_mango_nix() {
    assert_eq!(
        TOTAL_TAGS, 13,
        "layout now needs {TOTAL_TAGS} tags -- set tag_num and the tagrule \
         range in wrappedPrograms/mango.nix to match (mango's ceiling is 31)"
    );
}

#[test]
fn sticky_workspaces_are_the_same_tag_from_every_project() {
    for &sticky in &STICKY_TAGS {
        let seen: Vec<u8> = (1..=NUM_PROJECTS)
            .map(|p| real_tag(p, sticky).unwrap())
            .collect();
        assert!(
            seen.windows(2).all(|w| w[0] == w[1]),
            "sticky {sticky} differs per project: {seen:?}"
        );
    }
}

#[test]
fn every_project_workspace_maps_to_a_distinct_tag() {
    let mut seen = Vec::new();
    for project in 1..=NUM_PROJECTS {
        for &visible in &VISIBLE_SLOTS {
            seen.push(real_tag(project, visible).unwrap());
        }
    }
    for &sticky in &STICKY_TAGS {
        seen.push(real_tag(1, sticky).unwrap());
    }
    let mut sorted = seen.clone();
    sorted.sort_unstable();
    sorted.dedup();
    assert_eq!(
        sorted.len(),
        seen.len(),
        "two workspaces share a tag: {seen:?}"
    );
}

#[test]
fn the_mapping_covers_every_tag_mango_is_configured_for() {
    let mut seen = Vec::new();
    for project in 1..=NUM_PROJECTS {
        for visible in 1..=VISIBLE_TAGS {
            seen.push(real_tag(project, visible).unwrap());
        }
    }
    seen.sort_unstable();
    seen.dedup();
    assert_eq!(
        seen,
        (1..=TOTAL_TAGS).collect::<Vec<u8>>(),
        "layout leaves gaps or overshoots tag_num"
    );
    assert!(
        TOTAL_TAGS <= 31,
        "TOTAL_TAGS={TOTAL_TAGS} exceeds mango's limit"
    );
}

#[test]
fn slots_and_sticky_partition_the_key_row() {
    for visible in 1..=VISIBLE_TAGS {
        assert_ne!(
            is_slot(visible),
            is_sticky(visible),
            "workspace {visible} is both or neither"
        );
    }
}

#[test]
fn rejects_input_outside_the_range() {
    assert!(real_tag(0, 1).is_err());
    assert!(real_tag(NUM_PROJECTS + 1, 1).is_err());
    assert!(real_tag(1, 0).is_err());
    assert!(real_tag(1, VISIBLE_TAGS + 1).is_err());
}

#[test]
fn a_projects_home_tag_is_its_own_number() {
    for project in 1..=NUM_PROJECTS {
        assert_eq!(
            real_tag(project, HOME_SLOT).unwrap(),
            project,
            "switching to a project should land on the tag named after it"
        );
    }
}

#[test]
fn mru_returns_to_the_previous_project() {
    let mut st = State::default();
    st.record_switch(1, 2);
    assert_eq!(st.active, 2);
    assert_eq!(st.mru_next(), Some(1));

    st.record_switch(2, 3);
    assert_eq!(st.mru_next(), Some(2), "toggle hits the most recent, not 1");

    st.record_switch(3, 2);
    assert_eq!(st.active, 2);
    assert_eq!(
        st.mru_next(),
        Some(3),
        "active project is never its own target"
    );
}
