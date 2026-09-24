use crate::agents::{self, Activity, Agent, Burst};
use crate::devices::Device;
use crate::held;
use crate::mmsg;
use crate::paths::Dirs;
use crate::peers::{self, PeerView};
use crate::projects::{self, Library, Profile};
use crate::push;
use crate::slots::{self, VISIBLE_TAGS};
use crate::state::{self, Guard, State};
use crate::status;
use crate::{panes, tmux};
use anyhow::Result;
use serde_json::Value;
use std::collections::{HashMap, HashSet, VecDeque};
use std::io::Write;
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use std::time::SystemTime;

const POLL_INTERVAL: Duration = Duration::from_millis(40);

const FEED_RETRY: Duration = Duration::from_secs(1);

const DETAIL_INTERVAL_MS: u128 = 500;

#[derive(Debug, Default)]
pub struct Presence {
    project: Option<u8>,
}

impl Presence {
    pub fn project(&self) -> Option<u8> {
        self.project
    }

    pub fn focus(&mut self, real: Option<u8>) -> Option<u8> {
        let next = real.and_then(slots::project_for)?;
        if Some(next) == self.project {
            return None;
        }
        self.project.replace(next)
    }
}

fn follow_focus(dirs: &Dirs, presence: &Mutex<Presence>, windows: &Mutex<Vec<mmsg::Window>>) {
    loop {
        let _ = mmsg::watch_tags(|tags| {
            let left = held(presence).focus(tags.active);
            if let Some(left) = left {
                let seen = held(windows).clone();
                let _ = record_leaving(dirs, left, &seen);
            }
        });
        thread::sleep(FEED_RETRY);
    }
}

fn follow_windows(windows: &Mutex<Vec<mmsg::Window>>) {
    loop {
        let _ = mmsg::watch_windows(|seen| *held(windows) = seen);
        thread::sleep(FEED_RETRY);
    }
}

fn modified(path: &Path) -> Option<SystemTime> {
    std::fs::metadata(path).ok()?.modified().ok()
}

#[derive(Default)]
struct Fresh<T> {
    stamp: Option<SystemTime>,
    value: T,
}

impl<T> Fresh<T> {
    fn get(&mut self, path: &Path, load: impl FnOnce() -> T) -> &mut T {
        let stamp = modified(path);
        if stamp != self.stamp {
            self.value = load();
            self.stamp = stamp;
        }
        &mut self.value
    }

    fn spoil(&mut self) {
        self.stamp = None;
    }
}

fn learned(library: &mut Library, found: &[Agent], details: &Details, now: u128) -> bool {
    let mut learned = false;
    for agent in found {
        let Some(cwd) = details.get(agent.pid).map(|detail| detail.cwd.as_str()) else {
            continue;
        };
        learned |= library.adopt(agent.project, cwd, now);
        learned |= library.remember_dir(agent.project, cwd);
    }
    learned
}

fn learn_homes(dirs: &Dirs, shelf: &mut Fresh<Library>, found: &[Agent], details: &Details) {
    let now = agents::now_ms();
    let mut preview = shelf
        .get(&dirs.projects(), || {
            projects::load(dirs).unwrap_or_default()
        })
        .clone();
    if !learned(&mut preview, found, details, now) {
        return;
    }
    if let Ok(_guard) = Guard::acquire(dirs)
        && let Ok(mut library) = projects::load(dirs)
        && learned(&mut library, found, details, now)
    {
        let _ = projects::save(dirs, &library);
    }
    shelf.spoil();
}

fn record_leaving(dirs: &Dirs, project: u8, windows: &[mmsg::Window]) -> Result<()> {
    let _guard = Guard::acquire(dirs)?;
    let mut state = state::load(dirs)?;
    state.record_leaving(project);
    state::save(dirs, &state)?;
    shelve_if_deserted(dirs, project, windows)
}

pub fn holds_windows(project: u8, windows: &[mmsg::Window]) -> bool {
    windows
        .iter()
        .any(|window| project_of(window) == Some(project))
}

fn shelve_if_deserted(dirs: &Dirs, project: u8, windows: &[mmsg::Window]) -> Result<()> {
    let agents = agents::load_all(dirs)
        .iter()
        .filter(|agent| agent.project == project)
        .count();

    if !projects::deserted(holds_windows(project, windows), agents) {
        return Ok(());
    }
    let mut library = projects::load(dirs)?;
    library.clear(project);
    projects::save(dirs, &library)
}

pub fn newly_attending(before: &HashSet<u32>, now: &HashSet<u32>) -> Vec<u32> {
    let mut risen: Vec<u32> = now.difference(before).copied().collect();
    risen.sort_unstable();
    risen
}

fn attending(found: &[Agent], here: Option<u8>, state: &State, now: u128) -> HashSet<u32> {
    found
        .iter()
        .filter(|agent| {
            agents::needs_attention(agent, here, state.left_project_at(agent.project), now)
        })
        .map(|agent| agent.pid)
        .collect()
}

pub struct Watcher {
    cpu: CpuWatch,
    details: Details,
    presence: Arc<Mutex<Presence>>,
    windows: Arc<Mutex<Vec<mmsg::Window>>>,
    here_now: Fresh<State>,
    shelf: Fresh<Library>,
    host: String,
    peers: Arc<Mutex<Vec<PeerView>>>,
    devices: Arc<Mutex<Vec<Device>>>,
    port: u16,
    attending: HashSet<u32>,
}

impl Watcher {
    pub fn federated(
        dirs: &Dirs,
        peers: Arc<Mutex<Vec<PeerView>>>,
        devices: Arc<Mutex<Vec<Device>>>,
        port: u16,
    ) -> Self {
        let mut seed = Presence::default();
        if let Ok(tags) = mmsg::tag_state() {
            seed.focus(tags.active);
        }
        let presence = Arc::new(Mutex::new(seed));
        let windows = Arc::new(Mutex::new(mmsg::windows().unwrap_or_default()));

        {
            let windows = Arc::clone(&windows);
            thread::spawn(move || follow_windows(&windows));
        }
        {
            let presence = Arc::clone(&presence);
            let windows = Arc::clone(&windows);
            let dirs = dirs.clone();
            thread::spawn(move || follow_focus(&dirs, &presence, &windows));
        }

        Self {
            cpu: CpuWatch::default(),
            details: Details::default(),
            presence,
            windows,
            here_now: Fresh::default(),
            shelf: Fresh::default(),
            host: peers::here(),
            peers,
            devices,
            port,
            attending: HashSet::new(),
        }
    }

    fn alert(&mut self, dirs: &Dirs, attending: HashSet<u32>) {
        let risen = newly_attending(&self.attending, &attending);
        self.attending = attending;
        if risen.is_empty() {
            return;
        }
        let dirs = dirs.clone();
        let port = self.port;
        thread::spawn(move || {
            if let Some(subject) = push::subject(port) {
                push::notify(&dirs, &subject);
            }
        });
    }

    pub fn tick(&mut self, dirs: &Dirs) -> Result<Value> {
        let mut found = agents::load_all(dirs);
        agents::reap(dirs, &mut found);
        self.cpu.apply(&mut found);
        let seen = held(&self.windows).clone();
        self.details.refresh(dirs, &found, &seen, agents::now_ms());
        self.details.place(&mut found);
        found.sort_by_key(|agent| (agent.project, agent.pid));

        learn_homes(dirs, &mut self.shelf, &found, &self.details);

        let state = self
            .here_now
            .get(&dirs.state(), || state::load(dirs).unwrap_or_default())
            .clone();
        let here = held(&self.presence).project();
        let asking = attending(&found, here, &state, agents::now_ms());
        self.alert(dirs, asking.clone());

        let library = self.shelf.get(&dirs.projects(), || {
            projects::load(dirs).unwrap_or_default()
        });

        Ok(serde_json::to_value(Event {
            devices: held(&self.devices).clone(),
            ..Event::new(
                &state,
                &found,
                &asking,
                &self.details,
                library,
                self.host.clone(),
                held(&self.peers).clone(),
            )
        })?)
    }
}

pub fn latest(
    dirs: &Dirs,
    peers: Arc<Mutex<Vec<PeerView>>>,
    devices: Arc<Mutex<Vec<Device>>>,
    port: u16,
) -> Arc<Mutex<Option<Value>>> {
    let cell: Arc<Mutex<Option<Value>>> = Arc::new(Mutex::new(None));
    let into = Arc::clone(&cell);
    let dirs = dirs.clone();
    thread::spawn(move || {
        let mut watcher = Watcher::federated(&dirs, peers, devices, port);
        loop {
            if let Ok(event) = watcher.tick(&dirs) {
                *held(&into) = Some(event);
            }
            thread::sleep(POLL_INTERVAL);
        }
    });
    cell
}

pub fn run(
    dirs: &Dirs,
    peers: Arc<Mutex<Vec<PeerView>>>,
    devices: Arc<Mutex<Vec<Device>>>,
    port: u16,
) -> Result<()> {
    let stdout = std::io::stdout();
    let mut last: Option<String> = None;
    let mut watcher = Watcher::federated(dirs, peers, devices, port);

    loop {
        let line = serde_json::to_string(&watcher.tick(dirs)?)?;
        if last.as_deref() != Some(line.as_str()) {
            let mut lock = stdout.lock();
            writeln!(lock, "{line}")?;
            lock.flush()?;
            last = Some(line);
        }
        thread::sleep(POLL_INTERVAL);
    }
}

struct Sample {
    ticks: u64,
    burst: Option<(u128, Burst)>,
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
            let ticks = self.sample(agent);
            agent.activity =
                agents::unblocked_by_work(agent, self.busy_since_block(agent, now, ticks));
        }
    }

    fn sample(&mut self, agent: &Agent) -> u64 {
        let ticks = agents::cpu_ticks(agent.pid).unwrap_or(0);
        let sample = self
            .seen
            .entry(agent.pid)
            .or_insert(Sample { ticks, burst: None });
        sample.ticks = ticks;
        ticks
    }

    fn busy_since_block(&mut self, agent: &Agent, now: u128, ticks: u64) -> bool {
        let Some(sample) = self.seen.get_mut(&agent.pid) else {
            return false;
        };
        match &mut sample.burst {
            Some((at, burst)) if *at == agent.updated => burst.sustained(now, ticks),
            slot => {
                *slot = Some((agent.updated, Burst::opened(now, ticks)));
                false
            }
        }
    }
}

#[derive(serde::Serialize)]
struct Tag {
    visible: u8,
    real: u8,
    slot: bool,
}

pub fn owner_of<'a>(chain: &[u32], windows: &'a [mmsg::Window]) -> Option<&'a mmsg::Window> {
    chain
        .iter()
        .find_map(|pid| windows.iter().find(|window| window.pid == *pid))
}

pub fn project_of(window: &mmsg::Window) -> Option<u8> {
    window.tags.first().copied().and_then(slots::project_for)
}

#[derive(Default)]
struct Detail {
    cwd: String,
    title: String,
    window: Option<u32>,
    project: Option<u8>,
    status: Option<Value>,
    pane: Option<String>,
    size: Option<[u16; 2]>,
}

impl Detail {
    fn of(
        dirs: &Dirs,
        pid: u32,
        windows: &[mmsg::Window],
        panes: &[tmux::Pane],
        clients: &[tmux::Client],
    ) -> Self {
        let seat = panes::owner(&panes::chain(pid), panes);
        let ancestry = match seat.and_then(|pane| tmux::attached(clients, &pane.session)) {
            Some(client) => panes::chain(client),
            None => agents::ancestry(pid),
        };
        let owner = owner_of(&ancestry, windows);
        let cwd = agents::cwd(pid).unwrap_or_default();
        let title = owner.map(|window| window.title.clone()).unwrap_or_default();
        Self {
            title: if says_more_than(&title, &cwd) {
                title
            } else {
                String::new()
            },
            cwd,
            window: owner.map(|window| window.id),
            project: owner.and_then(project_of),
            status: status::load(dirs, pid),
            pane: seat.map(|pane| pane.number().to_owned()),
            size: seat.map(|pane| [pane.width, pane.height]),
        }
    }
}

fn says_more_than(title: &str, cwd: &str) -> bool {
    let title = title.trim();
    !title.is_empty()
        && title != cwd
        && Path::new(cwd)
            .file_name()
            .is_none_or(|base| base.to_string_lossy() != title)
}

#[derive(Default)]
struct Details {
    at: u128,
    seen: HashMap<u32, Detail>,
}

impl Details {
    fn refresh(&mut self, dirs: &Dirs, found: &[Agent], windows: &[mmsg::Window], now: u128) {
        if !self.seen.is_empty() && now.saturating_sub(self.at) < DETAIL_INTERVAL_MS {
            return;
        }
        self.at = now;
        let panes = tmux::panes().unwrap_or_default();
        let clients = tmux::clients();
        self.seen = found
            .iter()
            .map(|agent| {
                (
                    agent.pid,
                    Detail::of(dirs, agent.pid, windows, &panes, &clients),
                )
            })
            .collect();
        self.mute_shared_titles();
    }

    fn mute_shared_titles(&mut self) {
        let mut sharing: HashMap<u32, usize> = HashMap::new();
        for detail in self.seen.values() {
            if let Some(window) = detail.window {
                *sharing.entry(window).or_default() += 1;
            }
        }
        for detail in self.seen.values_mut() {
            if detail.window.is_some_and(|window| sharing[&window] > 1) {
                detail.title.clear();
            }
        }
    }

    fn get(&self, pid: u32) -> Option<&Detail> {
        self.seen.get(&pid)
    }

    fn place(&self, found: &mut [Agent]) {
        for agent in found.iter_mut() {
            if let Some(project) = self.get(agent.pid).and_then(|detail| detail.project) {
                agent.project = project;
            }
        }
    }
}

#[derive(serde::Serialize)]
struct AgentView {
    pid: u32,
    kind: String,
    project: u8,
    activity: Activity,
    attention: bool,
    notice: String,
    updated: u128,
    cwd: String,
    title: String,
    window: Option<u32>,
    status: Option<Value>,
    pane: Option<String>,
    size: Option<[u16; 2]>,
}

#[derive(serde::Serialize)]
struct Place {
    project: u8,
    name: String,
    icon: String,
    dir: String,
}

#[derive(serde::Serialize)]
struct Event<'a> {
    active: u8,
    mru: &'a VecDeque<u8>,
    project_count: u8,
    visible_slots: &'static [u8],
    tags: Vec<Tag>,
    agents: Vec<AgentView>,
    places: Vec<Place>,
    shelf: Vec<&'a Profile>,
    host: String,
    home: String,
    peers: Vec<PeerView>,
    devices: Vec<Device>,
}

impl<'a> Event<'a> {
    fn new(
        s: &'a State,
        found: &[Agent],
        asking: &HashSet<u32>,
        details: &Details,
        library: &'a Library,
        host: String,
        peers: Vec<PeerView>,
    ) -> Self {
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
            .map(|agent| {
                let detail = details.get(agent.pid);
                AgentView {
                    pid: agent.pid,
                    kind: agent.kind.clone(),
                    project: agent.project,
                    activity: agent.activity,
                    attention: asking.contains(&agent.pid),
                    notice: agent.notice.clone(),
                    updated: agent.updated,
                    cwd: detail.map(|d| d.cwd.clone()).unwrap_or_default(),
                    title: detail.map(|d| d.title.clone()).unwrap_or_default(),
                    window: detail.and_then(|d| d.window),
                    status: detail.and_then(|d| d.status.clone()),
                    pane: detail.and_then(|d| d.pane.clone()),
                    size: detail.and_then(|d| d.size),
                }
            })
            .collect();
        let places = (1..=slots::NUM_PROJECTS)
            .filter_map(|project| {
                library.at(project).map(|profile| Place {
                    project,
                    name: profile.name.clone(),
                    icon: profile.icon.clone(),
                    dir: profile.dir.clone(),
                })
            })
            .collect();

        Self {
            active,
            mru: &s.mru,
            project_count: slots::NUM_PROJECTS,
            visible_slots: &slots::VISIBLE_SLOTS,
            tags,
            agents,
            places,
            shelf: library.shelved(),
            host,
            home: crate::paths::home().to_string_lossy().into_owned(),
            peers,
            devices: Vec::new(),
        }
    }
}
