use vjproj::projects::{Library, named_after};

fn library() -> Library {
    Library::default()
}

#[test]
fn a_project_is_named_after_the_directory_its_agent_woke_up_in() {
    let mut shelf = library();
    assert!(shelf.adopt(3, "/home/yurii/nixconf", 100));

    let project = shelf.at(3).expect("project 3 took the directory's name");
    assert_eq!(project.name, "nixconf");
    assert_eq!(project.dir, "/home/yurii/nixconf");
}

#[test]
fn a_project_you_already_named_is_left_alone() {
    let mut shelf = library();
    shelf.describe(3, Some("Video".into()), Some("videocam".into()), None, 100);

    assert!(
        !shelf.adopt(3, "/home/yurii/clips", 200),
        "an occupied slot is never renamed behind your back"
    );
    assert_eq!(shelf.at(3).unwrap().name, "Video");
}

#[test]
fn a_named_project_still_learns_where_its_agent_lives() {
    let mut shelf = library();
    shelf.describe(2, Some("Web".into()), None, None, 100);

    assert!(shelf.remember_dir(2, "/home/yurii/cachix"));
    assert_eq!(shelf.at(2).unwrap().dir, "/home/yurii/cachix");

    assert!(
        !shelf.remember_dir(2, "/home/yurii/somewhere-else"),
        "a second agent in the same project does not move the project's home"
    );
    assert_eq!(shelf.at(2).unwrap().dir, "/home/yurii/cachix");
}

#[test]
fn coming_back_to_a_directory_reopens_the_project_you_left_there() {
    let mut shelf = library();
    shelf.adopt(1, "/home/yurii/nixconf", 100);
    let id = shelf.at(1).unwrap().id;
    shelf.clear(1);

    assert!(shelf.adopt(6, "/home/yurii/nixconf", 200));
    assert_eq!(
        shelf.at(6).unwrap().id,
        id,
        "the same directory is the same project, wherever you put it"
    );
    assert_eq!(shelf.profiles.len(), 1, "no duplicate was invented");
}

#[test]
fn a_project_already_on_the_bar_is_not_adopted_twice() {
    let mut shelf = library();
    shelf.adopt(1, "/home/yurii/nixconf", 100);

    assert!(shelf.adopt(4, "/home/yurii/nixconf", 200));
    assert_eq!(
        shelf.profiles.len(),
        2,
        "project 1 keeps its own; project 4 gets a second one of its own"
    );
    assert!(shelf.at(1).is_some());
    assert!(shelf.at(4).is_some());
}

#[test]
fn assigning_a_project_takes_it_off_wherever_it_was() {
    let mut shelf = library();
    let id = shelf.create("Game".into(), "sports_esports".into(), String::new(), 100);

    shelf.assign(2, id, 100);
    shelf.assign(7, id, 200);

    assert!(
        shelf.at(2).is_none(),
        "one project cannot sit in two places at once"
    );
    assert_eq!(shelf.at(7).unwrap().id, id);
}

#[test]
fn swapping_carries_each_project_to_the_others_place() {
    let mut shelf = library();
    let left = shelf.create("Video".into(), String::new(), String::new(), 100);
    let right = shelf.create("Web".into(), String::new(), String::new(), 100);
    shelf.assign(1, left, 100);
    shelf.assign(2, right, 100);

    shelf.swap(1, 2);
    assert_eq!(shelf.at(1).unwrap().id, right);
    assert_eq!(shelf.at(2).unwrap().id, left);
}

#[test]
fn swapping_onto_an_empty_slot_just_moves_the_project() {
    let mut shelf = library();
    let only = shelf.create("Video".into(), String::new(), String::new(), 100);
    shelf.assign(1, only, 100);

    shelf.swap(1, 5);
    assert!(shelf.at(1).is_none());
    assert_eq!(shelf.at(5).unwrap().id, only);
}

#[test]
fn the_shelf_offers_what_is_not_already_open_most_recent_first() {
    let mut shelf = library();
    let old = shelf.create("Old".into(), String::new(), String::new(), 100);
    let recent = shelf.create("Recent".into(), String::new(), String::new(), 300);
    let open = shelf.create("Open".into(), String::new(), String::new(), 400);
    shelf.assign(1, open, 400);

    let names: Vec<&str> = shelf
        .shelved()
        .iter()
        .map(|profile| profile.name.as_str())
        .collect();
    assert_eq!(names, vec!["Recent", "Old"]);
    assert_eq!(shelf.get(old).unwrap().name, "Old");
    assert_eq!(shelf.get(recent).unwrap().name, "Recent");
}

#[test]
fn forgetting_a_project_takes_it_off_the_bar_too() {
    let mut shelf = library();
    let id = shelf.create("Gone".into(), String::new(), String::new(), 100);
    shelf.assign(4, id, 100);

    shelf.forget(id);
    assert!(shelf.at(4).is_none());
    assert!(shelf.shelved().is_empty());
}

#[test]
fn you_can_move_a_project_somewhere_else_by_hand() {
    let mut shelf = library();
    shelf.adopt(1, "/home/yurii/nixconf", 100);

    shelf.describe(1, None, None, Some("/home/yurii/elsewhere".into()), 200);
    assert_eq!(shelf.at(1).unwrap().dir, "/home/yurii/elsewhere");
    assert_eq!(
        shelf.at(1).unwrap().name,
        "nixconf",
        "moving a project does not rename it"
    );
}

#[test]
fn walking_out_of_an_empty_project_closes_it() {
    assert!(
        vjproj::projects::deserted(false, 0),
        "nothing on the tag and nobody working means there is nothing to come back to"
    );
    assert!(
        !vjproj::projects::deserted(true, 0),
        "windows are still there, so the project is still open"
    );
    assert!(
        !vjproj::projects::deserted(false, 1),
        "an agent is still working in it, even with no window of its own"
    );
}

#[test]
fn a_project_shows_on_the_bar_once_anything_is_holding_it_open() {
    assert!(
        vjproj::projects::blank(false, false, 0),
        "no name, no windows and nobody working is not worth a tile"
    );
    assert!(
        !vjproj::projects::blank(true, false, 0),
        "a project you named stays on the bar even while it is empty"
    );
    assert!(!vjproj::projects::blank(false, true, 0));
    assert!(!vjproj::projects::blank(false, false, 1));
}

#[test]
fn closing_a_project_shelves_it_rather_than_burning_it() {
    let mut shelf = library();
    shelf.adopt(2, "/home/yurii/nixconf", 100);
    let id = shelf.at(2).unwrap().id;

    shelf.clear(2);
    assert!(shelf.at(2).is_none(), "the slot is free again");
    assert_eq!(
        shelf.shelved().iter().map(|p| p.id).collect::<Vec<_>>(),
        vec![id],
        "and the project is waiting in the picker, not gone"
    );
}

#[test]
fn a_directory_gives_up_its_last_component_as_a_name() {
    assert_eq!(named_after("/home/yurii/nixconf"), "nixconf");
    assert_eq!(named_after("/home/yurii/nixconf/"), "nixconf");
    assert_eq!(named_after("/"), "/");
    assert_eq!(named_after(""), "");
}
