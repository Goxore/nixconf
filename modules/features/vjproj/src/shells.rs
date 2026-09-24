use crate::held;
use std::sync::Mutex;
use std::time::{Duration, Instant};

pub const STALE: Duration = Duration::from_secs(300);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Opened {
    pub project: u8,
    pub pane: String,
}

struct Pristine {
    opened: Opened,
    since: Instant,
}

#[derive(Default)]
pub struct Untouched {
    inner: Mutex<Vec<Pristine>>,
}

impl Untouched {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn opened(&self, project: u8, pane: &str, now: Instant) {
        let mut kept = held(&self.inner);
        kept.retain(|one| one.opened.project != project);
        kept.push(Pristine {
            opened: Opened {
                project,
                pane: pane.to_owned(),
            },
            since: now,
        });
    }

    pub fn touched(&self, pane: &str) {
        held(&self.inner).retain(|one| one.opened.pane != pane);
    }

    pub fn released(&self, project: u8) -> Option<Opened> {
        let mut kept = held(&self.inner);
        let found = kept.iter().position(|one| one.opened.project == project)?;
        Some(kept.remove(found).opened)
    }

    pub fn stale(&self, now: Instant, after: Duration) -> Vec<Opened> {
        let mut kept = held(&self.inner);
        let (old, fresh): (Vec<_>, Vec<_>) = std::mem::take(&mut *kept)
            .into_iter()
            .partition(|one| now.duration_since(one.since) >= after);
        *kept = fresh;
        old.into_iter().map(|one| one.opened).collect()
    }

    pub fn waiting(&self) -> usize {
        held(&self.inner).len()
    }
}
