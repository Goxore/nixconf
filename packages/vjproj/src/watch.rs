use crate::agents::{self, Activity, Agent, Reporting};
use crate::paths::Dirs;
use crate::slots::{self, VISIBLE_TAGS};
use crate::state::{self, State};
use anyhow::Result;
use std::collections::{HashMap, VecDeque};
use std::io::Write;
use std::time::Duration;

const POLL_INTERVAL: Duration = Duration::from_millis(40);

const COARSE_GRACE_MS: u128 = 1500;

pub fn run(dirs: &Dirs) -> Result<()> {
    let stdout = std::io::stdout();
    let mut last: Option<String> = None;
    let mut cpu = CpuWatch::default();

    loop {
        let state = state::load(dirs).unwrap_or_default();
        let mut found = agents::load_all(dirs);
        agents::reap(dirs, &mut found);
        cpu.apply(&mut found);

        let line = serde_json::to_string(&Event::new(&state, &found))?;
        if last.as_deref() != Some(line.as_str()) {
            let mut lock = stdout.lock();
            writeln!(lock, "{line}")?;
            lock.flush()?;
            last = Some(line);
        }
        std::thread::sleep(POLL_INTERVAL);
    }
}

struct Sample {
    ticks: u64,
    active_at: u128,
}

#[derive(Default)]
struct CpuWatch {
    seen: HashMap<u32, Sample>,
}

impl CpuWatch {
    fn apply(&mut self, found: &mut [Agent]) {
        let now = agents::now_ms();
        self.seen
            .retain(|pid, _| found.iter().any(|agent| agent.pid == *pid));
        for agent in found.iter_mut() {
            if agent.reporting == Reporting::Coarse {
                agent.activity = self.infer(agent, now);
            }
        }
    }

    fn infer(&mut self, agent: &Agent, now: u128) -> Activity {
        let ticks = agents::cpu_ticks(agent.pid).unwrap_or(0);
        let sample = self.seen.entry(agent.pid).or_insert(Sample {
            ticks,
            active_at: 0,
        });
        if ticks > sample.ticks {
            sample.active_at = now;
        }
        sample.ticks = ticks;

        let busy = sample.active_at > agent.updated
            && now.saturating_sub(sample.active_at) < COARSE_GRACE_MS;
        if busy { Activity::Working } else { agent.activity }
    }
}

#[derive(serde::Serialize)]
struct Tag {
    visible: u8,
    real: u8,
    slot: bool,
}

#[derive(serde::Serialize)]
struct AgentView {
    pid: u32,
    kind: String,
    project: u8,
    activity: Activity,
    unread: bool,
}

#[derive(serde::Serialize)]
struct Event<'a> {
    active: u8,
    mru: &'a VecDeque<u8>,
    project_count: u8,
    visible_slots: &'static [u8],
    tags: Vec<Tag>,
    agents: Vec<AgentView>,
}

impl<'a> Event<'a> {
    fn new(s: &'a State, found: &[Agent]) -> Self {
        let active = if slots::valid_project(s.active) {
            s.active
        } else {
            1
        };
        let tags = (1..=VISIBLE_TAGS)
            .filter_map(|visible| {
                slots::real_tag(active, visible).ok().map(|real| Tag {
                    visible,
                    real,
                    slot: slots::is_slot(visible),
                })
            })
            .collect();
        let agents = found
            .iter()
            .map(|agent| AgentView {
                pid: agent.pid,
                kind: agent.kind.clone(),
                project: agent.project,
                activity: agent.activity,
                unread: agents::is_unread(agent, active, s.left_project_at(agent.project)),
            })
            .collect();
        Self {
            active,
            mru: &s.mru,
            project_count: slots::NUM_PROJECTS,
            visible_slots: &slots::VISIBLE_SLOTS,
            tags,
            agents,
        }
    }
}
