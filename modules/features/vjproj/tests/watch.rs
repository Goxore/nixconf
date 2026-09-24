use vjproj::mmsg::Window;
use vjproj::slots::{HOME_SLOT, NUM_PROJECTS, STICKY_TAGS, project_for, real_tag};
use vjproj::watch::{Presence, holds_windows, owner_of, project_of};

fn window(id: u32, pid: u32, tag: u8) -> Window {
    Window {
        id,
        pid,
        title: String::new(),
        tags: vec![tag],
    }
}

#[test]
fn an_agent_belongs_to_the_project_of_the_window_hosting_it() {
    let seen = vec![window(10, 500, real_tag(4, HOME_SLOT).unwrap())];
    let owner = owner_of(&[900, 800, 500], &seen).expect("the terminal is an ancestor");

    assert_eq!(
        project_of(owner),
        Some(4),
        "the window sits on project 4's home tag, so its agents do too"
    );
}

#[test]
fn the_nearest_window_ancestor_wins() {
    let seen = vec![
        window(10, 500, real_tag(4, HOME_SLOT).unwrap()),
        window(11, 800, real_tag(7, HOME_SLOT).unwrap()),
    ];
    let owner = owner_of(&[900, 800, 500], &seen).expect("both are ancestors");

    assert_eq!(
        project_of(owner),
        Some(7),
        "the terminal you are actually sitting in is the closer parent"
    );
}

#[test]
fn tabs_of_one_window_share_that_windows_project() {
    let seen = vec![window(10, 500, real_tag(2, HOME_SLOT).unwrap())];

    for tab in [601, 602, 603] {
        let owner = owner_of(&[tab, 500], &seen).expect("every tab hangs off the same window");
        assert_eq!(
            project_of(owner),
            Some(2),
            "tabs cannot be on different tags than the window drawing them"
        );
    }
}

#[test]
fn a_window_parked_on_a_shared_workspace_places_nobody() {
    let seen = vec![window(10, 500, real_tag(1, STICKY_TAGS[0]).unwrap())];
    let owner = owner_of(&[900, 500], &seen).unwrap();

    assert_eq!(
        project_of(owner),
        None,
        "a sticky tag names no project, so the agent keeps the one it was born with"
    );
}

#[test]
fn an_agent_with_no_window_is_placed_by_nobody() {
    let seen = vec![window(10, 500, real_tag(1, HOME_SLOT).unwrap())];
    assert!(
        owner_of(&[900, 800], &seen).is_none(),
        "an agent over ssh has no window to inherit a project from"
    );
}

#[test]
fn a_project_is_empty_when_nothing_sits_on_its_home_tag() {
    let seen = vec![
        window(10, 500, real_tag(2, HOME_SLOT).unwrap()),
        window(11, 600, real_tag(1, STICKY_TAGS[0]).unwrap()),
    ];

    assert!(holds_windows(2, &seen), "project 2 still has its window");
    assert!(
        !holds_windows(5, &seen),
        "project 5 was never opened, so leaving it closes nothing"
    );
    assert!(
        !holds_windows(1, &seen),
        "a window parked on a shared workspace belongs to no project, so project 1 is empty"
    );
    assert!(
        !holds_windows(2, &[]),
        "a dead window feed reads as empty rather than guessing"
    );
}

#[test]
fn a_home_tag_places_you_in_its_project() {
    for project in 1..=NUM_PROJECTS {
        assert_eq!(
            project_for(real_tag(project, HOME_SLOT).unwrap()),
            Some(project)
        );
    }
}

#[test]
fn a_sticky_tag_places_you_nowhere() {
    for &sticky in &STICKY_TAGS {
        assert_eq!(
            project_for(real_tag(1, sticky).unwrap()),
            None,
            "sticky workspace {sticky} belongs to every project, so to none"
        );
    }
}

#[test]
fn a_shared_workspace_does_not_take_you_out_of_your_project() {
    let mut presence = Presence::default();
    presence.focus(Some(real_tag(2, HOME_SLOT).unwrap()));
    assert_eq!(presence.project(), Some(2));

    let left = presence.focus(Some(real_tag(2, STICKY_TAGS[0]).unwrap()));
    assert_eq!(left, None, "stepping onto a scratch tag is not leaving");
    assert_eq!(
        presence.project(),
        Some(2),
        "sticky tags are shared by every project, so they take you out of none"
    );
}

#[test]
fn walking_between_projects_leaves_the_old_one() {
    let mut presence = Presence::default();
    presence.focus(Some(real_tag(1, HOME_SLOT).unwrap()));

    let left = presence.focus(Some(real_tag(3, HOME_SLOT).unwrap()));
    assert_eq!(left, Some(1));
    assert_eq!(presence.project(), Some(3));
}

#[test]
fn standing_still_is_not_leaving() {
    let mut presence = Presence::default();
    let home = real_tag(4, HOME_SLOT).unwrap();
    presence.focus(Some(home));

    assert_eq!(presence.focus(Some(home)), None);
    assert_eq!(presence.project(), Some(4));
}

#[test]
fn arriving_from_nowhere_leaves_nothing_behind() {
    let mut presence = Presence::default();
    assert_eq!(presence.project(), None);
    assert_eq!(presence.focus(Some(real_tag(5, HOME_SLOT).unwrap())), None);
    assert_eq!(presence.project(), Some(5));
}

#[test]
fn losing_the_tag_feed_leaves_you_where_you_were_last_seen() {
    let mut presence = Presence::default();
    presence.focus(Some(real_tag(6, HOME_SLOT).unwrap()));

    assert_eq!(presence.focus(None), None);
    assert_eq!(
        presence.project(),
        Some(6),
        "a dead feed is missing news, not proof that you walked away"
    );
}
