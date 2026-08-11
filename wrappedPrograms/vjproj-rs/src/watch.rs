use crate::paths::Dirs;
use crate::slots::{self, VISIBLE_TAGS};
use crate::state::{self, State};
use anyhow::Result;
use std::collections::VecDeque;
use std::io::Write;
use std::time::Duration;

const POLL_INTERVAL: Duration = Duration::from_millis(150);

pub fn run(dirs: &Dirs) -> Result<()> {
    let stdout = std::io::stdout();
    let mut last: Option<String> = None;

    loop {
        let state = state::load(dirs).unwrap_or_default();
        let line = serde_json::to_string(&Event::from(&state))?;
        if last.as_deref() != Some(line.as_str()) {
            let mut lock = stdout.lock();
            writeln!(lock, "{line}")?;
            lock.flush()?;
            last = Some(line);
        }
        std::thread::sleep(POLL_INTERVAL);
    }
}

#[derive(serde::Serialize)]
struct Tag {
    visible: u8,
    real: u8,
    slot: bool,
}

#[derive(serde::Serialize)]
struct Event<'a> {
    active: u8,
    mru: &'a VecDeque<u8>,
    current: u8,
    tags: Vec<Tag>,
}

impl<'a> From<&'a State> for Event<'a> {
    fn from(s: &'a State) -> Self {
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
        Self {
            active,
            mru: &s.mru,
            current: s.view_for(active),
            tags,
        }
    }
}
