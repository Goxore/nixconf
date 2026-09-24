use std::time::{Duration, Instant};
use vjproj::attach::{MOST, SETTLING, Size, crowded, from_hand, too_soon};
use vjproj::http::{Way, attaching, size_in};
use vjproj::tmux;

#[test]
fn a_pane_can_be_watched_and_spoken_to_on_two_sockets() {
    let watching = attaching("/pane/12/out").expect("out is an attach");
    assert_eq!(watching.pane, "12");
    assert_eq!(watching.way, Way::Out);
    assert_eq!(watching.peer, None);

    let speaking = attaching("/pane/12/in").expect("in is an attach");
    assert_eq!(speaking.way, Way::In);
}

#[test]
fn a_pane_on_another_machine_names_that_machine() {
    let asked = attaching("/at/mini/pane/7/out").expect("a peer pane is an attach");
    assert_eq!(asked.peer.as_deref(), Some("mini"));
    assert_eq!(asked.pane, "7");
    assert_eq!(asked.way, Way::Out);
}

#[test]
fn a_machine_cannot_be_asked_to_ask_a_third_machine() {
    assert_eq!(attaching("/at/mini/at/main/pane/7/out"), None);
}

#[test]
fn the_ordinary_routes_are_not_mistaken_for_terminals() {
    assert_eq!(attaching("/pane/12"), None);
    assert_eq!(attaching("/state"), None);
    assert_eq!(attaching("/pane/12/close"), None);
    assert_eq!(attaching("/"), None);
}

#[test]
fn a_phone_that_names_no_size_is_given_a_plain_one() {
    assert_eq!(size_in(None), Size::fitted(80, 24));
    assert_eq!(size_in(Some("token=abc")), Size::fitted(80, 24));
}

#[test]
fn a_phone_is_given_the_size_it_asked_for() {
    let asked = size_in(Some("cols=47&rows=33&token=abc"));
    assert_eq!(asked.cols, 47);
    assert_eq!(asked.rows, 33);
}

#[test]
fn a_size_no_terminal_could_hold_is_pulled_back_into_range() {
    assert_eq!(Size::fitted(1, 1).cols, tmux::NARROWEST);
    assert_eq!(Size::fitted(1, 1).rows, tmux::SHORTEST);
    assert_eq!(Size::fitted(9999, 9999).cols, tmux::WIDEST);
    assert_eq!(Size::fitted(9999, 9999).rows, tmux::TALLEST);
}

#[test]
fn what_the_terminal_answers_by_itself_is_not_someone_typing() {
    assert!(!from_hand(b"\x1b[?1;2c"));
    assert!(!from_hand(b"\x1b[24;80R"));
    assert!(!from_hand(b"\x1bP>|xterm\x1b\\"));
    assert!(!from_hand(b""));
}

#[test]
fn a_key_press_counts_as_someone_typing() {
    assert!(from_hand(b"a"));
    assert!(from_hand(b"\r"));
    assert!(from_hand(b"\x1b"));
    assert!(from_hand(b"\x1b[A"));
    assert!(from_hand(b"\x03"));
}

#[test]
fn a_terminal_reopened_in_a_tight_loop_is_turned_away() {
    let now = Instant::now();

    assert!(!too_soon(None, now), "the first attach is always fine");
    assert!(
        too_soon(Some(now), now + Duration::from_millis(50)),
        "a client that reconnects in a loop must be refused"
    );
    assert!(
        !too_soon(Some(now), now + SETTLING),
        "a client that waits is let back in"
    );
}

#[test]
fn no_client_can_open_more_terminals_than_we_allow() {
    assert!(!crowded(MOST - 1, false), "there is still room");
    assert!(crowded(MOST, false), "a new pane past the limit is refused");
    assert!(
        !crowded(MOST, true),
        "a pane already open may always be reattached"
    );
}
