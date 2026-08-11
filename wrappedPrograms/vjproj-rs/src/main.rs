use anyhow::Result;
use clap::{Parser, Subcommand};
use vjproj::paths::Dirs;
use vjproj::slots::{self, NUM_PROJECTS};
use vjproj::state::{self, Guard};
use vjproj::{mmsg, watch};

#[derive(Parser)]
#[command(name = "vjproj", about = "Project workspace groups for mango", version)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    View {
        workspace: u8,
    },
    Tag {
        workspace: u8,
    },
    ToggleView {
        workspace: u8,
    },
    ToggleTag {
        workspace: u8,
    },
    Left {
        #[arg(long)]
        occupied: bool,
    },
    Right {
        #[arg(long)]
        occupied: bool,
    },
    MoveLeft,
    MoveRight,
    Switch {
        project: u8,
    },
    Next,
    Status,
    Watch,
    Reset,
}

fn main() {
    if let Err(e) = run() {
        eprintln!("vjproj: {e:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    let dirs = Dirs::from_env()?;
    match cli.command {
        Command::View { workspace } => view(&dirs, workspace),
        Command::Tag { workspace } => remap(&dirs, workspace, mmsg::tag_focused),
        Command::ToggleView { workspace } => remap(&dirs, workspace, mmsg::toggle_view),
        Command::ToggleTag { workspace } => remap(&dirs, workspace, mmsg::toggle_tag),
        Command::Left { occupied } => step(&dirs, -1, occupied, false),
        Command::Right { occupied } => step(&dirs, 1, occupied, false),
        Command::MoveLeft => step(&dirs, -1, false, true),
        Command::MoveRight => step(&dirs, 1, false, true),
        Command::Switch { project } => switch(&dirs, project),
        Command::Next => next(&dirs),
        Command::Status => status(&dirs),
        Command::Watch => watch::run(&dirs),
        Command::Reset => reset(&dirs),
    }
}

fn view(dirs: &Dirs, workspace: u8) -> Result<()> {
    let _guard = Guard::acquire(dirs)?;
    let mut st = state::load(dirs)?;
    mmsg::view(slots::real_tag(st.active, workspace)?)?;
    if slots::is_slot(workspace) {
        st.record_view(st.active, workspace);
        state::save(dirs, &st)?;
    }
    Ok(())
}

fn step(dirs: &Dirs, dir: i8, occupied_only: bool, move_window: bool) -> Result<()> {
    let _guard = Guard::acquire(dirs)?;
    let mut st = state::load(dirs)?;
    let tags = mmsg::tag_state()?;

    let from = tags
        .active
        .and_then(|real| slots::visible_for(st.active, real))
        .unwrap_or_else(|| st.view_for(st.active));

    let mut next = from;
    let target = loop {
        let candidate = next as i16 + dir as i16;
        if candidate < 1 || candidate > slots::VISIBLE_TAGS as i16 {
            return Ok(());
        }
        next = candidate as u8;
        let real = slots::real_tag(st.active, next)?;
        if !occupied_only || tags.is_occupied(real) {
            break real;
        }
    };

    if move_window {
        return mmsg::tag_focused(target);
    }
    mmsg::view(target)?;
    if slots::is_slot(next) {
        st.record_view(st.active, next);
        state::save(dirs, &st)?;
    }
    Ok(())
}

fn remap(dirs: &Dirs, workspace: u8, action: fn(u8) -> Result<()>) -> Result<()> {
    let st = state::load(dirs)?;
    action(slots::real_tag(st.active, workspace)?)
}

fn switch(dirs: &Dirs, to: u8) -> Result<()> {
    slots::require_project(to)?;
    let _guard = Guard::acquire(dirs)?;
    let mut st = state::load(dirs)?;
    let from = st.active;
    let real = slots::real_tag(to, st.view_for(to))?;
    if from == to {
        return mmsg::view(real);
    }
    st.record_switch(from, to);
    state::save(dirs, &st)?;
    mmsg::view(real)
}

fn next(dirs: &Dirs) -> Result<()> {
    let target = {
        let st = state::load(dirs)?;
        st.mru_next()
            .unwrap_or_else(|| (st.active % NUM_PROJECTS) + 1)
    };
    switch(dirs, target)
}

fn status(dirs: &Dirs) -> Result<()> {
    let st = state::load(dirs)?;
    println!("{}", serde_json::to_string(&st)?);
    Ok(())
}

fn reset(dirs: &Dirs) -> Result<()> {
    let _guard = Guard::acquire(dirs)?;
    let st = state::State::default();
    state::save(dirs, &st)?;
    mmsg::view(slots::real_tag(st.active, st.view_for(st.active))?)
}
