use anyhow::Result;
use clap::{Parser, Subcommand};
use std::env;
use vjproj::agents::{self, Activity, Reporting};
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
    Agent {
        #[command(subcommand)]
        action: AgentAction,
    },
}

#[derive(Subcommand)]
enum AgentAction {
    Report {
        #[arg(long, value_enum)]
        activity: Activity,
    },
    End,
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
        Command::View { workspace } => remap(&dirs, workspace, mmsg::view),
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
        Command::Agent { action } => agent(&dirs, action),
    }
}

fn agent(dirs: &Dirs, action: AgentAction) -> Result<()> {
    let Some(pid) = env::var("VJAGENT_PID")
        .ok()
        .and_then(|v| v.trim().parse::<u32>().ok())
    else {
        return Ok(());
    };

    match action {
        AgentAction::End => {
            agents::forget(dirs, pid);
            Ok(())
        }
        AgentAction::Report { activity } => {
            let known = agents::load(dirs, pid);
            let project = match &known {
                Some(a) => a.project,
                None => state::load(dirs)?.active,
            };
            agents::record(
                dirs,
                &agents::Agent {
                    pid,
                    kind: env::var("VJAGENT_KIND").unwrap_or_else(|_| "agent".into()),
                    project,
                    activity,
                    reporting: match env::var("VJAGENT_REPORTING").as_deref() {
                        Ok("coarse") => Reporting::Coarse,
                        _ => Reporting::Precise,
                    },
                    updated: agents::now_ms(),
                },
            )
        }
    }
}

fn step(dirs: &Dirs, dir: i8, occupied_only: bool, move_window: bool) -> Result<()> {
    let st = state::load(dirs)?;
    let tags = mmsg::tag_state()?;

    let from = tags
        .active
        .and_then(|real| slots::visible_for(st.active, real))
        .unwrap_or(slots::HOME_SLOT);

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
    mmsg::view(target)
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
    let real = slots::real_tag(to, slots::HOME_SLOT)?;
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
    mmsg::view(slots::real_tag(st.active, slots::HOME_SLOT)?)
}
