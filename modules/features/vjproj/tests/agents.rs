use std::path::PathBuf;
use std::sync::atomic::{AtomicU32, Ordering};
use vjproj::agents::{self, Activity, Agent};
use vjproj::paths::Dirs;
use vjproj::state::State;

static COUNTER: AtomicU32 = AtomicU32::new(0);

const SETTLED: u128 = 1000 + agents::BLOCK_GRACE_MS;

fn scratch() -> Dirs {
    let unique = COUNTER.fetch_add(1, Ordering::Relaxed);
    let runtime: PathBuf =
        std::env::temp_dir().join(format!("vjproj-test-{}-{unique}", std::process::id()));
    let data = runtime.join("data");
    std::fs::create_dir_all(&data).unwrap();
    Dirs { runtime, data }
}

fn agent(pid: u32, project: u8, activity: Activity) -> Agent {
    Agent {
        pid,
        kind: "claude".into(),
        project,
        activity,
        updated: agents::now_ms(),
        notice: String::new(),
    }
}

#[test]
fn an_agent_survives_a_write_and_read() {
    let dirs = scratch();
    agents::record(&dirs, &agent(4242, 3, Activity::Blocked)).unwrap();

    let found = agents::load(&dirs, 4242).expect("agent should be on disk");
    assert_eq!(found.project, 3);
    assert_eq!(found.activity, Activity::Blocked);
    assert_eq!(found.kind, "claude");
}

#[test]
fn ending_an_agent_removes_it() {
    let dirs = scratch();
    agents::record(&dirs, &agent(4243, 1, Activity::Working)).unwrap();
    agents::forget(&dirs, 4243);

    assert!(agents::load(&dirs, 4243).is_none());
    assert!(agents::load_all(&dirs).is_empty());
}

#[test]
fn a_hook_arriving_after_the_session_ended_cannot_bring_it_back() {
    let dirs = scratch();
    agents::record(&dirs, &agent(u32::MAX, 1, Activity::Working)).unwrap();
    agents::end(&dirs, u32::MAX);

    assert!(
        agents::recently_ended(&dirs, u32::MAX),
        "the end has to be remembered, not just the record deleted"
    );
    assert!(agents::load(&dirs, u32::MAX).is_none());
}

#[test]
fn an_agent_still_running_stays_reachable_after_its_session_ends() {
    let dirs = scratch();
    let mine = std::process::id();
    agents::record(&dirs, &agent(mine, 1, Activity::Working)).unwrap();

    agents::end(&dirs, mine);

    assert!(
        agents::load(&dirs, mine).is_some(),
        "an agent you can still talk to must not vanish from the list"
    );

    let mut found = agents::load_all(&dirs);
    agents::reap(&dirs, &mut found);
    assert_eq!(found.len(), 1, "reaping must leave a living agent alone");
}

#[test]
fn an_end_marker_only_silences_a_process_that_actually_left() {
    let dirs = scratch();
    let mine = std::process::id();

    agents::record(&dirs, &agent(mine, 1, Activity::Working)).unwrap();
    agents::end(&dirs, mine);

    assert!(
        !agents::gone(&dirs, mine),
        "clearing a session ends it while the process lives on, so it may register again"
    );

    agents::end(&dirs, u32::MAX);
    assert!(
        agents::gone(&dirs, u32::MAX),
        "a pid that no longer exists is not coming back"
    );
}

#[test]
fn clearing_the_conversation_is_not_the_end_of_the_session() {
    assert!(agents::cleared(Some("clear")));

    for reason in ["logout", "prompt_input_exit", "other"] {
        assert!(
            !agents::cleared(Some(reason)),
            "{reason} really does end the session"
        );
    }
    assert!(
        !agents::cleared(None),
        "a hook that told us nothing is treated as a real ending"
    );
}

#[test]
fn reaping_forgets_a_session_that_ended_for_good() {
    let dirs = scratch();
    agents::record(&dirs, &agent(u32::MAX, 1, Activity::Working)).unwrap();
    agents::end(&dirs, u32::MAX);

    let mut found = agents::load_all(&dirs);
    agents::reap(&dirs, &mut found);

    assert!(
        agents::load_all(&dirs).is_empty(),
        "an end marker must not read back as an agent"
    );
}

#[test]
fn agents_are_grouped_by_project() {
    let dirs = scratch();
    agents::record(&dirs, &agent(30, 3, Activity::Idle)).unwrap();
    agents::record(&dirs, &agent(10, 1, Activity::Idle)).unwrap();
    agents::record(&dirs, &agent(20, 1, Activity::Idle)).unwrap();

    let order: Vec<(u8, u32)> = agents::load_all(&dirs)
        .iter()
        .map(|a| (a.project, a.pid))
        .collect();
    assert_eq!(order, vec![(1, 10), (1, 20), (3, 30)]);
}

#[test]
fn a_dead_agent_is_reaped_from_disk() {
    let dirs = scratch();
    let mine = std::process::id();
    agents::record(&dirs, &agent(mine, 1, Activity::Working)).unwrap();
    agents::record(&dirs, &agent(u32::MAX, 2, Activity::Working)).unwrap();

    let mut found = agents::load_all(&dirs);
    agents::reap(&dirs, &mut found);

    assert_eq!(found.len(), 1, "only the live agent should remain");
    assert_eq!(found[0].pid, mine);
    assert!(
        agents::load(&dirs, u32::MAX).is_none(),
        "reaping should delete the stale file, not just hide it"
    );
}

#[test]
fn a_finished_agent_waits_for_you_until_you_go_back() {
    let mut done = agent(50, 2, Activity::Idle);
    done.updated = 1000;

    assert!(
        agents::needs_attention(&done, Some(1), 500, SETTLED),
        "finished after you left project 2, and you have not returned"
    );
    assert!(
        !agents::needs_attention(&done, Some(2), 500, SETTLED),
        "you are standing in project 2, so there is nothing to tell you"
    );
    assert!(
        !agents::needs_attention(&done, Some(1), 2000, SETTLED),
        "you already visited project 2 after it finished"
    );
}

#[test]
fn an_agent_started_without_a_window_can_be_told_where_it_lives() {
    assert_eq!(agents::pinned(Some("4")), Some(4));
    assert_eq!(agents::pinned(Some(" 4\n")), Some(4));
}

#[test]
fn a_nonsense_pin_falls_back_to_wherever_you_are_standing() {
    assert_eq!(agents::pinned(None), None);
    assert_eq!(agents::pinned(Some("")), None);
    assert_eq!(agents::pinned(Some("nine")), None);
    assert_eq!(agents::pinned(Some("0")), None);
    assert_eq!(agents::pinned(Some("99")), None);
}

#[test]
fn a_shared_workspace_is_nobody_s_project() {
    let mut done = agent(53, 2, Activity::Idle);
    done.updated = 1000;

    assert!(
        agents::needs_attention(&done, None, 500, SETTLED),
        "sitting on a sticky workspace is not sitting in project 2"
    );
}

#[test]
fn a_blocked_agent_glows_until_it_is_unblocked() {
    let mut asking = agent(52, 2, Activity::Blocked);
    asking.updated = 1000;

    assert!(
        agents::needs_attention(&asking, Some(1), 500, SETTLED),
        "it started asking while you were away, so it has to shout"
    );
    assert!(
        agents::needs_attention(&asking, Some(2), 500, SETTLED),
        "standing next to it is not answering it"
    );
    assert!(
        agents::needs_attention(&asking, Some(1), 2000, SETTLED),
        "visiting is not answering either; only the agent can call it resolved"
    );
}

#[test]
fn a_block_that_answers_itself_never_gets_to_shout() {
    let mut asking = agent(54, 2, Activity::Blocked);
    asking.updated = 1000;

    assert!(
        !agents::needs_attention(&asking, Some(1), 500, 1000),
        "an approval an auto-reviewer is about to grant is not yours to answer"
    );
    assert!(
        !agents::needs_attention(&asking, Some(1), 500, 1000 + agents::BLOCK_GRACE_MS - 1),
        "still inside the grace, still not your problem"
    );
    assert!(
        agents::needs_attention(&asking, Some(1), 500, 1000 + agents::BLOCK_GRACE_MS),
        "nothing else answered it, so now it really is waiting on you"
    );
}

#[test]
fn a_block_the_agent_worked_through_stops_shouting() {
    let asking = agent(70, 2, Activity::Blocked);

    assert_eq!(
        agents::unblocked_by_work(&asking, false),
        Activity::Blocked,
        "an agent waiting on a human is not computing an answer"
    );
    assert_eq!(
        agents::unblocked_by_work(&asking, true),
        Activity::Working,
        "once it is computing again the question was already answered"
    );
}

#[test]
fn cpu_never_invents_a_block_that_was_not_reported() {
    for activity in [Activity::Working, Activity::Idle] {
        let quiet = agent(71, 2, activity);
        assert_eq!(
            agents::unblocked_by_work(&quiet, true),
            activity,
            "burning cpu only ever clears a block, it never sets one"
        );
    }
}

#[test]
fn a_burst_of_real_work_reads_as_busy() {
    let mut burst = agents::Burst::opened(0, 1_000);
    assert!(
        burst.sustained(200, 1_000 + agents::BLOCKED_BUSY_TICKS),
        "half a core for a fifth of a second is an agent computing, not a prompt drawing itself"
    );
}

#[test]
fn a_prompt_drawing_itself_never_adds_up_to_work() {
    let idle_rate = 9;
    let mut burst = agents::Burst::opened(0, 0);
    let mut ticks = 0;

    for second in 1..=600u128 {
        ticks += idle_rate;
        assert!(
            !burst.sustained(second * 1_000, ticks),
            "a terminal redrawing at {idle_rate} ticks a second was still called busy after {second}s"
        );
    }
}

#[test]
fn the_window_slides_instead_of_latching() {
    let mut burst = agents::Burst::opened(0, 0);
    let almost = agents::BLOCKED_BUSY_TICKS - 1;

    assert!(!burst.sustained(agents::BLOCKED_BUSY_WINDOW_MS, almost));
    assert!(
        !burst.sustained(agents::BLOCKED_BUSY_WINDOW_MS + 1, almost * 2),
        "the window reopened, so the ticks burned before it no longer count"
    );
}

#[test]
fn a_working_agent_never_asks_for_attention() {
    let mut busy = agent(51, 2, Activity::Working);
    busy.updated = 1000;
    assert!(
        !agents::needs_attention(&busy, Some(1), 0, SETTLED),
        "working shows its own colour, attention is for what waits on you"
    );
    assert!(
        !agents::needs_attention(&busy, None, 0, SETTLED),
        "answering a permission puts it back to work and stops the glow"
    );
}

fn notice<'a>(kind: &'a str, message: &'a str) -> agents::Notice<'a> {
    agents::Notice {
        kind: Some(kind),
        message: Some(message),
    }
}

#[test]
fn a_notification_mid_turn_means_it_is_asking_you_something() {
    let busy = agent(60, 1, Activity::Working);
    assert_eq!(
        agents::notified(
            Some(&busy),
            notice(
                "permission_prompt",
                "Claude needs your permission to use Bash"
            )
        ),
        Some(Activity::Blocked)
    );
    assert_eq!(
        agents::notified(None, agents::Notice::default()),
        Some(Activity::Blocked),
        "an agent we have never heard from is asking, not idling"
    );
}

#[test]
fn a_notification_after_the_turn_ended_disturbs_nothing() {
    let done = agent(61, 1, Activity::Idle);
    assert_eq!(
        agents::notified(Some(&done), agents::Notice::default()),
        None,
        "an agent already at rest has nothing left to tell us"
    );
}

#[test]
fn the_idle_nag_puts_a_stranded_agent_back_to_rest() {
    let stranded = agent(62, 1, Activity::Working);
    assert_eq!(
        agents::notified(Some(&stranded), notice("idle_prompt", "")),
        Some(Activity::Idle),
        "an interrupted turn leaves working behind; the nag is how we learn it is over"
    );
    assert_eq!(
        agents::notified(Some(&stranded), notice("agent_completed", "")),
        Some(Activity::Idle),
        "a finished turn is rest, not a question"
    );
}

#[test]
fn prose_is_only_read_when_the_type_is_missing() {
    let stranded = agent(63, 1, Activity::Working);
    let untyped = |message| agents::Notice {
        kind: None,
        message: Some(message),
    };

    assert_eq!(
        agents::notified(Some(&stranded), untyped("Claude is waiting for your input")),
        Some(Activity::Idle)
    );
    assert_eq!(
        agents::notified(
            Some(&stranded),
            untyped("Claude needs your permission to use Bash")
        ),
        Some(Activity::Blocked)
    );
    assert_eq!(
        agents::notified(
            Some(&stranded),
            notice("permission_prompt", "Claude is waiting for your input")
        ),
        Some(Activity::Blocked),
        "a type we understand outranks whatever the sentence happens to say"
    );

    assert!(agents::idle_nag("Claude is waiting for your input"));
    assert!(!agents::idle_nag(
        "Claude needs your permission to use Bash"
    ));
}

#[test]
fn a_blocked_agent_remembers_what_it_is_asking() {
    let busy = agent(64, 1, Activity::Working);
    assert_eq!(
        agents::carried(
            Some(&busy),
            Activity::Blocked,
            Some("  Claude needs your permission to use Bash\n")
        ),
        "Claude needs your permission to use Bash",
        "the question is the whole point of the notification"
    );

    let dirs = scratch();
    let mut asking = agent(64, 1, Activity::Blocked);
    asking.notice = agents::carried(Some(&busy), Activity::Blocked, Some("Bash: rm -rf build"));
    agents::record(&dirs, &asking).unwrap();

    assert_eq!(
        agents::load(&dirs, 64)
            .expect("agent should be on disk")
            .notice,
        "Bash: rm -rf build"
    );
}

#[test]
fn going_back_to_work_forgets_the_question() {
    let mut asking = agent(65, 1, Activity::Blocked);
    asking.notice = "Claude needs your permission to use Bash".into();

    assert_eq!(
        agents::carried(Some(&asking), Activity::Working, None),
        "",
        "an answered question must not keep hanging over the agent"
    );
    assert_eq!(
        agents::carried(Some(&asking), Activity::Idle, None),
        "Claude needs your permission to use Bash",
        "a report that says nothing new leaves the question standing"
    );
}

#[test]
fn a_question_too_long_to_read_is_cut_short() {
    let rambling = "a".repeat(500);
    assert_eq!(agents::gist(&rambling).chars().count(), 200);
    assert_eq!(agents::gist("short enough"), "short enough");
}

#[test]
fn a_question_written_in_another_alphabet_is_cut_between_letters() {
    let rambling = "ї".repeat(500);
    let cut = agents::gist(&rambling);

    assert_eq!(cut.chars().count(), 200, "letters are counted, not bytes");
    assert_eq!(cut, "ї".repeat(200));
    assert_eq!(agents::gist(" привіт "), "привіт");
}

#[test]
fn an_agent_recorded_before_notices_existed_still_reads_back() {
    let dirs = scratch();
    let raw = r#"{"pid":66,"kind":"claude","project":2,"activity":"blocked","updated":1000}"#;
    std::fs::create_dir_all(dirs.agents()).unwrap();
    std::fs::write(dirs.agents().join("66.json"), raw).unwrap();

    let found = agents::load(&dirs, 66).expect("an older record must still load");
    assert_eq!(found.notice, "");
}

#[test]
fn leaving_a_project_marks_when_you_last_saw_it() {
    let mut st = State::default();
    assert_eq!(st.left_project_at(1), 0, "never left means never seen");

    st.record_leaving(1);
    assert!(st.left_project_at(1) > 0, "leaving 1 records the moment");
    assert_eq!(st.left_project_at(2), 0, "arriving at 2 records nothing");
}

#[test]
fn switching_projects_does_not_pretend_you_were_there() {
    let mut st = State::default();
    st.record_switch(1, 2);
    assert_eq!(
        st.left_project_at(1),
        0,
        "only the focused tag decides when you left, not the project you picked"
    );
}

#[test]
fn liveness_and_cpu_come_from_proc() {
    let mine = std::process::id();
    assert!(agents::alive(mine));
    assert!(!agents::alive(u32::MAX));
    assert!(agents::cpu_ticks(mine).is_some());
    assert!(agents::cpu_ticks(u32::MAX).is_none());
}
