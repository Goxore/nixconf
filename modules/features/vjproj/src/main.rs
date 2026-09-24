use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::env;
use std::io::{IsTerminal, Read};
use std::net::Ipv4Addr;
use std::sync::Arc;
use vjproj::agents::{self, Activity};
use vjproj::paths::{self, Dirs};
use vjproj::state::{self, Guard};
use vjproj::switch;
use vjproj::{auth, devices, http, mmsg, peers, projects, slots, tailnet, watch};

const DEFAULT_PORT: u16 = 8422;

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
        target: u8,
        #[arg(long)]
        position: bool,
    },
    Send {
        target: u8,
        #[arg(long)]
        position: bool,
    },
    Next,
    Focus {
        project: u8,
        #[arg(long)]
        window: Option<u32>,
    },
    Fresh,
    Dir {
        #[arg(long)]
        project: Option<u8>,
    },
    Status,
    Watch {
        #[arg(long, default_value_t = DEFAULT_PORT)]
        port: u16,
        #[arg(long = "machine")]
        machines: Vec<String>,
    },
    Serve {
        #[arg(long, default_value_t = DEFAULT_PORT)]
        port: u16,
        #[arg(long)]
        bind: Option<Ipv4Addr>,
        #[arg(long)]
        www: Option<std::path::PathBuf>,
        #[arg(long = "machine")]
        machines: Vec<String>,
    },
    Url {
        #[arg(long, default_value_t = DEFAULT_PORT)]
        port: u16,
        #[arg(long)]
        host: Option<String>,
    },
    Reset,
    Agent {
        #[command(subcommand)]
        action: AgentAction,
    },
    Project {
        #[command(subcommand)]
        action: ProjectAction,
    },
}

#[derive(Subcommand)]
enum ProjectAction {
    List,
    Assign {
        project: u8,
        id: u32,
    },
    Describe {
        project: u8,
        #[arg(long)]
        name: Option<String>,
        #[arg(long)]
        icon: Option<String>,
        #[arg(long)]
        dir: Option<String>,
    },
    Clear {
        project: u8,
    },
    Swap {
        from: u8,
        to: u8,
    },
    Forget {
        id: u32,
    },
}

#[derive(Subcommand)]
enum AgentAction {
    Report {
        #[arg(long, value_enum)]
        activity: Activity,
    },
    Notify,
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
        Command::Switch { target, position } => match aimed(&dirs, target, position)? {
            Some(project) => switch(&dirs, project),
            None => Ok(()),
        },
        Command::Send { target, position } => match aimed(&dirs, target, position)? {
            Some(project) => send(project),
            None => Ok(()),
        },
        Command::Next => next(&dirs),
        Command::Focus { project, window } => focus(&dirs, project, window),
        Command::Fresh => fresh(&dirs),
        Command::Dir { project } => print_dir(&dirs, project),
        Command::Status => status(&dirs),
        Command::Watch { port, machines } => {
            let machines = peers::machines(machines);
            let known = peers::watch(port, machines.clone());
            let found = devices::watch(&dirs, machines, Arc::clone(&known));
            watch::run(&dirs, known, found, port)
        }
        Command::Serve {
            port,
            bind,
            www,
            machines,
        } => serve(&dirs, port, bind, www, machines),
        Command::Url { port, host } => url(&dirs, port, host),
        Command::Reset => reset(&dirs),
        Command::Agent { action } => agent(&dirs, action),
        Command::Project { action } => project(&dirs, action),
    }
}

fn project(dirs: &Dirs, action: ProjectAction) -> Result<()> {
    if let ProjectAction::List = action {
        println!("{}", serde_json::to_string(&projects::load(dirs)?)?);
        return Ok(());
    }

    let _guard = Guard::acquire(dirs)?;
    let mut library = projects::load(dirs)?;
    let now = agents::now_ms();

    match action {
        ProjectAction::List => unreachable!("listing never reaches the writing path"),
        ProjectAction::Assign { project, id } => {
            slots::require_project(project)?;
            library.assign(project, id, now);
        }
        ProjectAction::Describe {
            project,
            name,
            icon,
            dir,
        } => {
            slots::require_project(project)?;
            library.describe(project, name, icon, dir, now);
        }
        ProjectAction::Clear { project } => {
            slots::require_project(project)?;
            library.clear(project);
        }
        ProjectAction::Swap { from, to } => {
            slots::require_project(from)?;
            slots::require_project(to)?;
            library.swap(from, to);
            carry_windows(from, to)?;
        }
        ProjectAction::Forget { id } => library.forget(id),
    }
    projects::save(dirs, &library)
}

fn carry_windows(from: u8, to: u8) -> Result<()> {
    if from == to {
        return Ok(());
    }
    let here = slots::real_tag(from, slots::HOME_SLOT)?;
    let there = slots::real_tag(to, slots::HOME_SLOT)?;
    let windows = mmsg::windows()?;

    for window in &windows {
        let Some(&tag) = window.tags.first() else {
            continue;
        };
        if tag == here {
            mmsg::retag_window(window.id, there)?;
        } else if tag == there {
            mmsg::retag_window(window.id, here)?;
        }
    }
    Ok(())
}

fn fresh(dirs: &Dirs) -> Result<()> {
    match vjproj::free_project(dirs)? {
        Some(project) => switch(dirs, project),
        None => Ok(()),
    }
}

fn print_dir(dirs: &Dirs, project: Option<u8>) -> Result<()> {
    let project = match project {
        Some(project) => project,
        None => state::load(dirs)?.active,
    };
    let library = projects::load(dirs)?;
    let dir = library
        .at(project)
        .map(|profile| profile.dir.clone())
        .filter(|dir| !dir.is_empty())
        .unwrap_or_else(|| paths::home().to_string_lossy().into_owned());
    println!("{dir}");
    Ok(())
}

fn agent(dirs: &Dirs, action: AgentAction) -> Result<()> {
    let Some(pid) = env::var("VJAGENT_PID")
        .ok()
        .and_then(|v| v.trim().parse::<u32>().ok())
    else {
        return Ok(());
    };

    let known = agents::load(dirs, pid);
    match action {
        AgentAction::End => {
            let payload = hook_payload();
            if agents::cleared(field(&payload, "reason")) || agents::alive(pid) {
                return record(dirs, pid, known, Activity::Idle, None);
            }
            agents::end(dirs, pid);
            Ok(())
        }
        AgentAction::Report { activity } => record(dirs, pid, known, activity, None),
        AgentAction::Notify => {
            let payload = hook_payload();
            let notice = agents::Notice {
                kind: field(&payload, "notification_type"),
                message: field(&payload, "message"),
            };
            match agents::notified(known.as_ref(), notice) {
                Some(activity) => record(dirs, pid, known, activity, notice.message),
                None => Ok(()),
            }
        }
    }
}

fn hook_payload() -> Option<serde_json::Value> {
    let stdin = std::io::stdin();
    if stdin.is_terminal() {
        return None;
    }
    let mut raw = String::new();
    stdin.lock().read_to_string(&mut raw).ok()?;
    serde_json::from_str(&raw).ok()
}

fn field<'a>(payload: &'a Option<serde_json::Value>, name: &str) -> Option<&'a str> {
    payload.as_ref()?.get(name)?.as_str()
}

fn record(
    dirs: &Dirs,
    pid: u32,
    known: Option<agents::Agent>,
    activity: Activity,
    message: Option<&str>,
) -> Result<()> {
    if known.is_none() && agents::gone(dirs, pid) {
        return Ok(());
    }
    let project = match &known {
        Some(a) => a.project,
        None => match agents::pinned(env::var("VJAGENT_PROJECT").ok().as_deref()) {
            Some(project) => project,
            None => state::load(dirs)?.active,
        },
    };
    let notice = agents::carried(known.as_ref(), activity, message);
    agents::record(
        dirs,
        &agents::Agent {
            pid,
            kind: env::var("VJAGENT_KIND").unwrap_or_else(|_| "agent".into()),
            project,
            activity,
            updated: agents::now_ms(),
            notice,
        },
    )
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

fn aimed(dirs: &Dirs, target: u8, position: bool) -> Result<Option<u8>> {
    if position {
        return vjproj::project_at(dirs, target);
    }
    Ok(Some(target))
}

fn send(to: u8) -> Result<()> {
    slots::require_project(to)?;
    mmsg::tag_focused(slots::real_tag(to, slots::HOME_SLOT)?)
}

fn next(dirs: &Dirs) -> Result<()> {
    let active = state::load(dirs)?.active;
    let occupied = mmsg::tag_state()?.occupied;
    switch(dirs, slots::next_occupied(active, &occupied))
}

fn focus(dirs: &Dirs, project: u8, window: Option<u32>) -> Result<()> {
    switch(dirs, project)?;
    match window {
        Some(id) => mmsg::focus_window(id),
        None => Ok(()),
    }
}

fn serve(
    dirs: &Dirs,
    port: u16,
    bind: Option<Ipv4Addr>,
    editing: Option<std::path::PathBuf>,
    machines: Vec<String>,
) -> Result<()> {
    let address = match bind {
        Some(address) => address,
        None => tailnet::wait(),
    };
    let machines = peers::machines(machines);
    let known = peers::watch(port, machines.clone());
    let found = devices::watch(dirs, machines.clone(), Arc::clone(&known));
    let serving = http::Serving {
        dirs: dirs.clone(),
        latest: watch::latest(dirs, Arc::clone(&known), Arc::clone(&found), port),
        devices: found,
        token: auth::token(dirs)?,
        www: www()?,
        editing,
        port,
        peers: known,
        trust: auth::Trust::of_tailnet(machines),
        shells: vjproj::shells::Untouched::new(),
        attaching: vjproj::attach::Attached::new(),
    };
    http::serve(http::bind(address, port)?, serving)
}

fn url(dirs: &Dirs, port: u16, host: Option<String>) -> Result<()> {
    let token = auth::token(dirs)?;
    if host.is_none()
        && let Some(fronted) = tailnet::fronted(port)
    {
        println!("https://{fronted}/#{token}");
        return Ok(());
    }
    let host = match host {
        Some(host) => host,
        None => tailnet::address()?.to_string(),
    };
    println!("http://{host}:{port}/#{token}");
    Ok(())
}

fn www() -> Result<std::path::PathBuf> {
    std::env::var_os("VJPROJ_WWW")
        .map(std::path::PathBuf::from)
        .context("VJPROJ_WWW is not set")
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
