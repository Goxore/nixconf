use vjproj::panes;
use vjproj::tmux::{self, Pane};

const LISTING: &str = "\
2001\t%0\tnixconf\t120\t40\t/home/yurii/nixconf
2044\t%3\tvideos\t80\t24\t/home/yurii/NewVideos
";

fn listed() -> Vec<Pane> {
    tmux::parse_panes(LISTING)
}

#[test]
fn a_listing_becomes_panes() {
    let panes = listed();
    assert_eq!(panes.len(), 2);
    assert_eq!(panes[0].pid, 2001);
    assert_eq!(panes[0].id, "%0");
    assert_eq!(panes[0].session, "nixconf");
    assert_eq!(panes[0].width, 120);
    assert_eq!(panes[0].height, 40);
    assert_eq!(panes[0].dir, "/home/yurii/nixconf");
    assert_eq!(panes[1].number(), "3");
}

#[test]
fn a_ragged_line_is_dropped_rather_than_guessed_at() {
    assert!(tmux::parse_panes("nonsense").is_empty());
    assert!(tmux::parse_panes("2001\t%0\tonly\tthree").is_empty());
    assert!(tmux::parse_panes("").is_empty());
}

#[test]
fn a_directory_with_spaces_survives_the_split() {
    let panes = tmux::parse_panes("7\t%1\ts\t80\t24\t/home/yurii/My Videos\n");
    assert_eq!(panes[0].dir, "/home/yurii/My Videos");
}

#[test]
fn an_agent_is_matched_to_the_pane_that_contains_it() {
    let panes = listed();
    assert_eq!(panes::owner(&[9999, 2044], &panes).unwrap().id, "%3");
}

#[test]
fn the_nearest_ancestor_wins_when_panes_are_nested() {
    let panes = listed();
    assert_eq!(panes::owner(&[2044, 2001], &panes).unwrap().id, "%3");
}

#[test]
fn an_agent_outside_tmux_has_no_pane() {
    assert!(panes::owner(&[4, 5, 6], &listed()).is_none());
}

#[test]
fn a_pane_target_is_only_ever_a_number() {
    assert_eq!(tmux::target("3").unwrap(), "%3");
    assert!(tmux::target("").is_err());
    assert!(tmux::target("3; kill-server").is_err());
    assert!(tmux::target("%3").is_err());
}
