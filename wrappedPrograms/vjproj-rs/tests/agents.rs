use std::path::PathBuf;
use std::sync::atomic::{AtomicU32, Ordering};
use vjproj::agents::{self, Activity, Agent, Reporting};
use vjproj::paths::Dirs;

static COUNTER: AtomicU32 = AtomicU32::new(0);

fn scratch() -> Dirs {
    let unique = COUNTER.fetch_add(1, Ordering::Relaxed);
    let runtime: PathBuf =
        std::env::temp_dir().join(format!("vjproj-test-{}-{unique}", std::process::id()));
    std::fs::create_dir_all(&runtime).unwrap();
    Dirs { runtime }
}

fn agent(pid: u32, project: u8, activity: Activity) -> Agent {
    Agent {
        pid,
        kind: "claude".into(),
        project,
        activity,
        reporting: Reporting::Precise,
        updated: agents::now_ms(),
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
fn liveness_and_cpu_come_from_proc() {
    let mine = std::process::id();
    assert!(agents::alive(mine));
    assert!(!agents::alive(u32::MAX));
    assert!(agents::cpu_ticks(mine).is_some());
    assert!(agents::cpu_ticks(u32::MAX).is_none());
}
