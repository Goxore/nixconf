use std::time::{Duration, Instant};
use vjproj::shells::Untouched;

fn now() -> Instant {
    Instant::now()
}

#[test]
fn a_shell_nobody_typed_into_is_closed_when_you_leave() {
    let shells = Untouched::new();
    shells.opened(3, "9", now());

    let released = shells.released(3).expect("a pristine shell is closed");

    assert_eq!(released.project, 3);
    assert_eq!(released.pane, "9");
    assert_eq!(shells.waiting(), 0);
}

#[test]
fn a_shell_you_typed_into_survives_leaving() {
    let shells = Untouched::new();
    shells.opened(3, "9", now());

    shells.touched("9");

    assert!(shells.released(3).is_none(), "typed-in shells must persist");
    assert_eq!(shells.waiting(), 0);
}

#[test]
fn typing_into_one_shell_leaves_another_alone() {
    let shells = Untouched::new();
    shells.opened(1, "4", now());
    shells.opened(2, "5", now());

    shells.touched("4");

    assert!(shells.released(1).is_none());
    assert_eq!(shells.released(2).map(|one| one.pane), Some("5".to_owned()));
}

#[test]
fn a_shell_that_was_already_open_is_never_tracked() {
    let shells = Untouched::new();

    assert!(shells.released(7).is_none());
    assert_eq!(shells.waiting(), 0);
}

#[test]
fn reopening_a_project_replaces_the_pane_we_are_watching() {
    let shells = Untouched::new();
    shells.opened(2, "5", now());
    shells.opened(2, "8", now());

    assert_eq!(shells.waiting(), 1);
    assert_eq!(shells.released(2).map(|one| one.pane), Some("8".to_owned()));
}

#[test]
fn a_phone_that_never_comes_back_still_loses_its_untouched_shell() {
    let shells = Untouched::new();
    let opened = now();
    shells.opened(4, "2", opened);

    let swept = shells.stale(opened + Duration::from_secs(600), Duration::from_secs(300));

    assert_eq!(swept.len(), 1);
    assert_eq!(swept[0].project, 4);
    assert_eq!(shells.waiting(), 0);
}

#[test]
fn a_shell_opened_a_moment_ago_is_not_swept_yet() {
    let shells = Untouched::new();
    let opened = now();
    shells.opened(4, "2", opened);

    let swept = shells.stale(opened + Duration::from_secs(10), Duration::from_secs(300));

    assert!(swept.is_empty());
    assert_eq!(shells.waiting(), 1);
}

#[test]
fn sweeping_never_reaches_a_shell_somebody_typed_into() {
    let shells = Untouched::new();
    let opened = now();
    shells.opened(4, "2", opened);
    shells.touched("2");

    let swept = shells.stale(opened + Duration::from_secs(600), Duration::from_secs(300));

    assert!(swept.is_empty());
}

#[test]
fn closing_a_pane_by_hand_stops_us_closing_it_again() {
    let shells = Untouched::new();
    shells.opened(5, "3", now());

    shells.touched("3");

    assert!(shells.released(5).is_none());
}
