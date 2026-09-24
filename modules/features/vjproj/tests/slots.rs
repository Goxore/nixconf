use vjproj::slots::{
    HOME_SLOT, NUM_PROJECTS, STICKY_TAGS, TOTAL_TAGS, VISIBLE_SLOTS, VISIBLE_TAGS, is_slot,
    is_sticky, next_occupied, nth_open, real_tag,
};

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
    assert_eq!(
        real_tag(1, 1).unwrap(),
        1,
        "workspace 1 is the project itself"
    );
    assert_eq!(real_tag(9, 1).unwrap(), 9);
    assert_eq!(real_tag(1, 2).unwrap(), 10, "sticky ignores the project");
    assert_eq!(real_tag(9, 2).unwrap(), 10);
    assert_eq!(real_tag(1, 3).unwrap(), 11);
    assert_eq!(real_tag(9, 3).unwrap(), 11);
    assert_eq!(real_tag(3, 9).unwrap(), 17);
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
        TOTAL_TAGS, 17,
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
    const _: () = assert!(TOTAL_TAGS <= 31, "TOTAL_TAGS exceeds mango's limit");
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
fn sending_a_window_targets_the_projects_own_tag() {
    for project in 1..=NUM_PROJECTS {
        assert_eq!(
            real_tag(project, HOME_SLOT).unwrap(),
            real_tag(1, HOME_SLOT).unwrap() + project - 1,
            "send must land on the destination project, not the active one"
        );
    }
    assert!(real_tag(NUM_PROJECTS + 1, HOME_SLOT).is_err());
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
fn the_number_row_counts_along_the_bar_rather_than_by_slot() {
    let open = [1, 4, 5, 8];

    assert_eq!(nth_open(1, &open), Some(1));
    assert_eq!(nth_open(2, &open), Some(4), "the second tile, not slot 2");
    assert_eq!(nth_open(4, &open), Some(8));
}

#[test]
fn a_key_past_the_end_of_the_bar_lands_nowhere() {
    assert_eq!(nth_open(5, &[1, 4, 5, 8]), None);
    assert_eq!(nth_open(1, &[]), None, "an empty bar has no first tile");
    assert_eq!(nth_open(0, &[1, 4]), None, "the bar starts counting at one");
}

#[test]
fn tab_walks_forward_through_the_projects_in_use() {
    let occupied: Vec<u8> = [1, 4, 7]
        .iter()
        .map(|&p| real_tag(p, HOME_SLOT).unwrap())
        .collect();

    assert_eq!(next_occupied(1, &occupied), 4);
    assert_eq!(next_occupied(4, &occupied), 7);
    assert_eq!(
        next_occupied(7, &occupied),
        1,
        "past the last one it comes back round to the first"
    );
}

#[test]
fn tab_steps_over_projects_with_nothing_in_them() {
    let occupied = vec![real_tag(5, HOME_SLOT).unwrap()];
    assert_eq!(
        next_occupied(1, &occupied),
        5,
        "2, 3 and 4 are empty, so they are not worth stopping at"
    );
}

#[test]
fn tab_never_counts_a_shared_workspace_as_somebody_being_home() {
    let occupied = vec![real_tag(1, STICKY_TAGS[0]).unwrap()];
    assert_eq!(
        next_occupied(1, &occupied),
        2,
        "a sticky tag is the same tag in every project, so it makes none of them busy"
    );
}

#[test]
fn tab_on_a_bare_desktop_still_moves_one_along() {
    assert_eq!(next_occupied(1, &[]), 2);
    assert_eq!(
        next_occupied(NUM_PROJECTS, &[]),
        1,
        "with nowhere in use it degrades to plain counting"
    );
}

#[test]
fn tab_leaves_a_project_even_when_it_is_the_only_one_in_use() {
    let occupied = vec![real_tag(3, HOME_SLOT).unwrap()];
    assert_eq!(
        next_occupied(3, &occupied),
        4,
        "you are already here, so the only way on is the next one along"
    );
}
