pub mod agents;
pub mod attach;
pub mod auth;
pub mod devices;
pub mod http;
pub mod launch;
pub mod mmsg;
pub mod panes;
pub mod paths;
pub mod peers;
pub mod projects;
pub mod push;
pub mod shells;
pub mod slots;
pub mod state;
pub mod status;
pub mod tailnet;
pub mod tmux;
pub mod watch;

use anyhow::{Context, Result, bail};
use paths::Dirs;
use state::Guard;
use std::sync::{Mutex, MutexGuard};

pub fn held<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

pub fn free_project(dirs: &Dirs) -> Result<Option<u8>> {
    let library = projects::load(dirs)?;
    let occupied = mmsg::tag_state()?.occupied;
    let taken = |project: u8| {
        library.at(project).is_some()
            || occupied
                .iter()
                .any(|&real| slots::project_for(real) == Some(project))
    };
    Ok((1..=slots::NUM_PROJECTS).find(|&project| !taken(project)))
}

pub fn open_projects(dirs: &Dirs) -> Result<Vec<u8>> {
    let library = projects::load(dirs)?;
    let occupied = mmsg::tag_state()?.occupied;
    let working = agents::load_all(dirs);
    Ok((1..=slots::NUM_PROJECTS)
        .filter(|&project| {
            !projects::blank(
                library
                    .at(project)
                    .is_some_and(|profile| !profile.name.is_empty()),
                occupied
                    .iter()
                    .any(|&real| slots::project_for(real) == Some(project)),
                working
                    .iter()
                    .filter(|agent| agent.project == project)
                    .count(),
            )
        })
        .collect())
}

pub fn project_at(dirs: &Dirs, position: u8) -> Result<Option<u8>> {
    Ok(slots::nth_open(position, &open_projects(dirs)?))
}

pub fn project_dir(dirs: &Dirs, project: u8) -> Result<std::path::PathBuf> {
    slots::require_project(project)?;
    let library = projects::load(dirs)?;
    let dir = library
        .at(project)
        .map(|profile| profile.dir.clone())
        .filter(|dir| !dir.is_empty())
        .with_context(|| format!("project {project} has no directory yet"))?;
    Ok(std::path::PathBuf::from(dir))
}

pub fn create_project(dirs: &Dirs, dir: &std::path::Path) -> Result<u8> {
    let dir = paths::home_dir(dir)?;
    let dir = dir.to_string_lossy().into_owned();

    let _guard = Guard::acquire(dirs)?;
    let mut library = projects::load(dirs)?;

    if let Some(slot) = library
        .profiles
        .iter()
        .find(|profile| profile.dir == dir)
        .and_then(|profile| library.slot_of(profile.id))
    {
        return Ok(slot);
    }

    let Some(slot) = free_project(dirs)? else {
        bail!("every project slot is taken");
    };
    library.adopt(slot, &dir, agents::now_ms());
    projects::save(dirs, &library)?;
    Ok(slot)
}

pub fn adopt_shelf(dirs: &Dirs, id: u32) -> Result<u8> {
    let _guard = Guard::acquire(dirs)?;
    let mut library = projects::load(dirs)?;

    if let Some(slot) = library.slot_of(id) {
        return Ok(slot);
    }
    if library.get(id).is_none() {
        bail!("no project with id {id}");
    }

    let Some(slot) = free_project(dirs)? else {
        bail!("every project slot is taken");
    };
    library.assign(slot, id, agents::now_ms());
    projects::save(dirs, &library)?;
    Ok(slot)
}

pub fn switch(dirs: &Dirs, to: u8) -> Result<()> {
    slots::require_project(to)?;
    let _guard = Guard::acquire(dirs)?;
    let mut st = state::load(dirs)?;
    let from = st.active;
    let real = slots::real_tag(to, slots::HOME_SLOT)?;
    if from == to {
        return mmsg::view(real);
    }
    st.record_switch(from, to);
    state::save(dirs, &st)?;

    let mut library = projects::load(dirs)?;
    library.touch(to, agents::now_ms());
    projects::save(dirs, &library)?;

    mmsg::view(real)
}
