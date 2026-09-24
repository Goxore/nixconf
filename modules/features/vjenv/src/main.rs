mod config;
mod devshell;
mod emit;
mod identity;
mod paths;
mod project;
mod registry;
mod root;
mod searchpath;
mod session;
mod shellinit;
mod undo;

use anyhow::{Context as _, Result, bail};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::Shell as CompletionShell;
use config::Config;
use emit::{EnvOp, Shell, render};
use paths::Dirs;
use project::Project;
use registry::{ENV_ALLOW, ENV_DENY, Registry};
use root::{RealFs, RootKind};
use session::Env;
use std::io::Write as _;
use std::path::{Path, PathBuf};

#[derive(Parser)]
#[command(
    name = "vjenv",
    about = "Directory-scoped identity and dev environments",
    version,
    disable_help_subcommand = true
)]
struct Cli {
    #[arg(long, global = true, value_name = "DIR")]
    cwd: Option<PathBuf>,

    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    Status,
    Env {
        #[arg(value_name = "SHELL", default_value = "posix")]
        shell: String,
        #[arg(long)]
        no_devshell: bool,
    },
    Assign {
        #[arg(long, value_name = "NAME")]
        identity: Option<String>,
    },
    Use {
        #[arg(value_name = "IDENTITY", required_unless_present = "clear")]
        identity: Option<String>,
        #[arg(long, conflicts_with = "identity")]
        clear: bool,
        #[arg(long, default_value = "fish")]
        shell: String,
    },
    Exec {
        #[arg(trailing_var_arg = true, required = true, value_name = "CMD")]
        argv: Vec<String>,
    },
    Shells,
    Allow {
        #[arg(value_name = "DEVSHELL")]
        devshell: Option<String>,
    },
    Deny,
    Reload,
    Gc {
        #[arg(long)]
        dry_run: bool,
    },
    Shellinit {
        #[arg(value_name = "SHELL", default_value = "fish")]
        shell: String,
    },
    Completions {
        #[arg(value_name = "SHELL")]
        shell: CompletionShell,
    },
}

fn main() {
    if let Err(e) = run() {
        eprintln!("vjenv: {e:#}");
        std::process::exit(1);
    }
}

struct App {
    dirs: Dirs,
    config: Config,
    registry: Registry,
    cwd: PathBuf,
    env: Env,
    system: String,
    flake_loader: Option<PathBuf>,
}

impl App {
    fn load(cwd: Option<PathBuf>) -> Result<Self> {
        let dirs = Dirs::from_env()?;
        let cwd = match cwd {
            Some(d) => d
                .canonicalize()
                .with_context(|| format!("no such directory: {}", d.display()))?,
            None => std::env::current_dir().context("cannot determine the working directory")?,
        };
        let config = Config::load(&dirs)?;
        let registry = Registry::load(&dirs.registry())?;
        let env: Env = std::env::vars_os()
            .filter_map(|(k, v)| Some((k.into_string().ok()?, v.into_string().ok()?)))
            .collect();
        Ok(Self {
            dirs,
            config,
            registry,
            cwd,
            system: env
                .get("VJENV_SYSTEM")
                .cloned()
                .unwrap_or_else(|| "x86_64-linux".into()),
            flake_loader: env.get("VJENV_FLAKE_LOADER").map(PathBuf::from),
            env,
        })
    }

    fn var(&self, name: &str) -> Option<&str> {
        self.env
            .get(name)
            .map(String::as_str)
            .filter(|v| !v.is_empty())
    }

    fn root(&self) -> Option<(PathBuf, RootKind)> {
        root::resolve(&self.cwd, &self.config.roots, &RealFs)
    }

    fn require_root(&self) -> Result<PathBuf> {
        match self.root() {
            Some((r, _)) => Ok(r),
            None => bail!(
                "{} is not inside a known project.\n       \
                 declare it under [roots] in {},\n       \
                 or drop a marker file at the project root.",
                self.cwd.display(),
                self.dirs.identity_toml().display()
            ),
        }
    }

    fn identity_of(&self, root: Option<&Path>) -> (Option<String>, bool) {
        if let Some(o) = self.var("VJENV_OVERRIDE") {
            return (Some(o.to_string()), true);
        }
        let id = root
            .and_then(|r| self.registry.get(r))
            .and_then(|e| e.identity.clone());
        (id, false)
    }

    fn identity_ops(&self) -> Vec<EnvOp> {
        let root = self.root().map(|(r, _)| r);
        let (id, pinned) = self.identity_of(root.as_deref());
        let resolved = id
            .as_deref()
            .and_then(|i| self.config.identity(i).map(|d| (i, d)));

        identity::env_ops(&identity::Context {
            dirs: &self.dirs,
            root: root.as_deref(),
            id: resolved.map(|(i, _)| i),
            identity: resolved.map(|(_, d)| d),
            pinned,
            jj_config_current: self.var("JJ_CONFIG"),
        })
    }

    fn sync_jj_fragment(&self, id: &str) -> Result<()> {
        let Some(identity) = self.config.identity(id) else {
            return Ok(());
        };
        let path = self.dirs.jj_config(id);
        let wanted = identity::jj_config_toml(identity);
        if std::fs::read_to_string(&path).ok().as_deref() == Some(wanted.as_str()) {
            return Ok(());
        }
        paths::atomic_write(&path, wanted.as_bytes())
    }

    fn project(&self) -> Option<Project> {
        project::find(&self.cwd, &self.dirs.home)
    }

    fn require_project(&self) -> Result<Project> {
        self.project().with_context(|| {
            format!(
                "no flake.nix, devenv.nix or flake/flake.nix at or above {}",
                self.cwd.display()
            )
        })
    }

    fn loader(&self) -> devshell::Loader<'_> {
        devshell::Loader {
            dirs: &self.dirs,
            system: &self.system,
            flake_loader: self.flake_loader.as_deref(),
        }
    }

    fn verdict(&self, project: &Project) -> Option<&str> {
        self.registry
            .get(&project.dir)
            .and_then(|e| e.env.as_deref())
    }

    fn chosen_shell(&self, project: &Project) -> Option<&str> {
        self.registry
            .get(&project.dir)
            .and_then(|e| e.shell.as_deref())
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();

    if let Command::Completions { shell } = cli.command {
        let mut cmd = Cli::command();
        let name = cmd.get_name().to_string();
        clap_complete::generate(shell, &mut cmd, name, &mut std::io::stdout());
        return Ok(());
    }

    let app = App::load(cli.cwd)?;

    match cli.command {
        Command::Completions { .. } => unreachable!("handled above"),
        Command::Status => status(&app),
        Command::Env { shell, no_devshell } => env(&app, &shell, no_devshell),
        Command::Assign { identity } => assign(&app, identity),
        Command::Use {
            identity,
            clear,
            shell,
        } => use_identity(&app, identity, clear, &shell),
        Command::Exec { argv } => exec(&app, argv),
        Command::Shells => {
            for s in app.loader().shells(&app.require_project()?)? {
                println!("{s}");
            }
            Ok(())
        }
        Command::Allow { devshell } => gate(&app, ENV_ALLOW, devshell),
        Command::Deny => gate(&app, ENV_DENY, None),
        Command::Reload => reload(&app),
        Command::Gc { dry_run } => gc(&app, dry_run),
        Command::Shellinit { shell } => {
            if Shell::parse(&shell) != Some(Shell::Fish) {
                bail!("shellinit only supports fish");
            }
            let exe = std::env::current_exe().context("cannot locate the vjenv binary")?;
            print!("{}", shellinit::fish(&exe));
            Ok(())
        }
    }
}

struct Plan {
    ops: Vec<EnvOp>,
    offer: Option<(PathBuf, String)>,
}

enum Outcome {
    Keep,
    Unload,
    Load(devshell::DevEnv, String, String),
    Failed(String),
    Offer(PathBuf, String),
}

fn plan(app: &App, with_devshell: bool) -> Result<Plan> {
    let mut ops = app.identity_ops();
    let identity = active_identity(&ops);
    if let Some(id) = &identity {
        app.sync_jj_fragment(id)?;
    }

    let mut base_path = app.var("PATH").unwrap_or_default().to_string();
    let mut dev_path = Vec::new();

    let outcome = match with_devshell {
        true => devshell_outcome(app),
        false => Outcome::Keep,
    };
    if !matches!(outcome, Outcome::Keep) {
        let next = match &outcome {
            Outcome::Load(env, root, stamp) => Some(session::Loading { env, root, stamp }),
            _ => None,
        };
        let t = session::transition(&app.env, next);
        ops.extend(t.ops);
        base_path = t.base_path;
        dev_path = t.dev_path;
        ops.push(match &outcome {
            Outcome::Failed(stamp) => EnvOp::set(session::FAILED_VAR, stamp),
            _ => EnvOp::unset(session::FAILED_VAR),
        });
    }
    let offer = match outcome {
        Outcome::Offer(dir, stamp) => {
            let token = format!("{}@{stamp}", dir.display());
            Some((dir, token))
        }
        _ => None,
    };

    let composed = searchpath::compose(
        &base_path,
        &dev_path,
        app.var(searchpath::GATED_DIR_VAR),
        identity.is_some(),
    );
    ops.push(EnvOp::list(
        "PATH",
        searchpath::split(&composed).map(str::to_string).collect(),
    ));
    Ok(Plan { ops, offer })
}

fn devshell_outcome(app: &App) -> Outcome {
    let loaded = app.var(session::ROOT_VAR);
    let idle = || match loaded {
        Some(_) => Outcome::Unload,
        None => Outcome::Keep,
    };

    let Some(project) = app.project() else {
        return idle();
    };
    let stamp = project.stamp();

    match app.verdict(&project) {
        Some(ENV_ALLOW) => {}
        Some(ENV_DENY) => return idle(),
        _ => return Outcome::Offer(project.dir, stamp),
    }

    if loaded == Some(project.dir.to_string_lossy().as_ref())
        && app.var(session::STAMP_VAR) == Some(stamp.as_str())
    {
        return Outcome::Keep;
    }
    if app.var(session::FAILED_VAR) == Some(stamp.as_str()) {
        return idle();
    }

    let base = session::base(&app.env);
    match app
        .loader()
        .load(&project, app.chosen_shell(&project), &base)
    {
        Ok(dev) => Outcome::Load(
            dev,
            project.dir.to_string_lossy().into_owned(),
            project.stamp(),
        ),
        Err(e) => {
            eprintln!("vjenv: {e:#}");
            Outcome::Failed(project.stamp())
        }
    }
}

fn active_identity(ops: &[EnvOp]) -> Option<String> {
    ops.iter().find_map(|o| match o {
        EnvOp::Set(n, v) if n == "VJENV_IDENTITY" => Some(v.clone()),
        _ => None,
    })
}

fn env(app: &App, shell: &str, no_devshell: bool) -> Result<()> {
    let shell = Shell::parse(shell)
        .with_context(|| format!("unknown shell '{shell}' (want fish or posix)"))?;

    let plan = plan(app, !no_devshell)?;
    let pending: Vec<EnvOp> = plan
        .ops
        .into_iter()
        .filter(|op| !op.matches(app.env.get(op.name()).map(String::as_str)))
        .collect();

    let mut text = render(&pending, shell);
    if shell == Shell::Fish
        && let Some((dir, token)) = plan.offer
    {
        text.push_str(&format!(
            "set -g __vjenv_env_pending {}\nset -g __vjenv_env_token {}\n",
            emit::quote(&dir.to_string_lossy(), Shell::Fish),
            emit::quote(&token, Shell::Fish),
        ));
    }

    std::io::stdout().lock().write_all(text.as_bytes())?;
    Ok(())
}

fn exec(app: &App, argv: Vec<String>) -> Result<()> {
    use std::os::unix::process::CommandExt;

    let mut cmd = std::process::Command::new(&argv[0]);
    cmd.args(&argv[1..]);
    for op in plan(app, true)?.ops {
        match op {
            EnvOp::Set(k, v) => cmd.env(k, v),
            EnvOp::SetList(k, entries) => cmd.env(k, entries.join(":")),
            EnvOp::Unset(k) => cmd.env_remove(k),
        };
    }
    Err(anyhow::Error::from(cmd.exec()).context(format!("cannot run {}", argv[0])))
}

fn status(app: &App) -> Result<()> {
    let Some((root, kind)) = app.root() else {
        println!("identity : none — not inside a known project");
        println!("cwd      : {}", app.cwd.display());
        env_status(app);
        return Ok(());
    };
    let (id, pinned) = app.identity_of(Some(&root));

    println!("{:<9}: {} ({})", "root", root.display(), kind.as_str());
    match id.as_deref() {
        None => println!(
            "{:<9}: unassigned (run: vjenv assign --identity <name>)",
            "identity"
        ),
        Some(id) => {
            let via = if pinned { " (override)" } else { "" };
            println!("{:<9}: {id}{via}", "identity");
            match app.config.identity(id) {
                None => println!(
                    "{:<9}: WARNING — '{id}' is not declared in {}",
                    "",
                    app.dirs.identity_toml().display()
                ),
                Some(d) => {
                    println!(
                        "{:<9}: {} <{}>",
                        "git",
                        d.name.as_deref().unwrap_or("—"),
                        d.email.as_deref().unwrap_or("—")
                    );
                    println!(
                        "{:<9}: {}",
                        "ssh key",
                        d.ssh_key
                            .as_ref()
                            .map_or("—".into(), |k| k.display().to_string())
                    );
                }
            }
        }
    }

    env_status(app);
    Ok(())
}

fn env_status(app: &App) {
    let Some(project) = app.project() else { return };
    let mut state = match app.verdict(&project) {
        Some(s) => s.to_string(),
        None => "not allowed yet (asked on entry)".into(),
    };
    if let Some(which) = app.chosen_shell(&project) {
        state = format!("{state}, devShell {which}");
    }
    println!("{:<9}: {} [{state}]", "env", project.dir.display());
    if let Some(loaded) = app.var(session::ROOT_VAR) {
        println!("{:<9}: {loaded}", "loaded");
    }
}

fn assign(app: &App, identity: Option<String>) -> Result<()> {
    let root = app.require_root()?;

    if let Some(id) = &identity
        && !app.config.identities.contains_key(id)
    {
        bail!(
            "no such identity '{id}' — declared: [{}]",
            app.config.identity_names().join(", ")
        );
    }

    Registry::update(&app.dirs.registry(), |reg| {
        let entry = reg.entry_mut(&root);
        if let Some(id) = identity {
            entry.identity = Some(id);
        }
        Ok(())
    })?;

    status(&App::load(Some(root))?)
}

fn use_identity(app: &App, identity: Option<String>, clear: bool, shell: &str) -> Result<()> {
    let shell = Shell::parse(shell).with_context(|| format!("unknown shell '{shell}'"))?;
    let op = if clear {
        EnvOp::unset("VJENV_OVERRIDE")
    } else {
        let id = identity.expect("clap requires an identity unless --clear");
        if !app.config.identities.contains_key(&id) {
            bail!(
                "no such identity '{id}' — declared: [{}]",
                app.config.identity_names().join(", ")
            );
        }
        EnvOp::set("VJENV_OVERRIDE", id)
    };
    print!("{}", render(&[op], shell));
    Ok(())
}

fn gate(app: &App, verdict: &str, devshell: Option<String>) -> Result<()> {
    let project = app.require_project()?;
    let devshell = devshell.filter(|d| !d.is_empty());
    Registry::update(&app.dirs.registry(), |reg| {
        let entry = reg.entry_mut(&project.dir);
        entry.env = Some(verdict.into());
        if verdict == ENV_ALLOW
            && let Some(name) = devshell.clone()
        {
            entry.shell = Some(name);
        }
        Ok(())
    })?;
    match devshell {
        Some(name) if verdict == ENV_ALLOW => {
            println!(
                "vjenv: {} marked allow, devShell {name}",
                project.dir.display()
            )
        }
        _ => println!("vjenv: {} marked {verdict}", project.dir.display()),
    }
    Ok(())
}

fn reload(app: &App) -> Result<()> {
    let project = app.require_project()?;
    app.loader().forget(&project, app.chosen_shell(&project))?;
    println!(
        "vjenv: {} will be evaluated again on the next entry",
        project.dir.display()
    );
    Ok(())
}

fn gc(app: &App, dry_run: bool) -> Result<()> {
    let gone: Vec<String> = app
        .registry
        .entries
        .keys()
        .filter(|k| !Path::new(k).is_dir())
        .cloned()
        .collect();
    let dead = app.loader().dead();

    for k in &gone {
        println!("registry: {k}");
    }
    for c in &dead {
        println!("cache   : {}", c.display());
    }
    if gone.is_empty() && dead.is_empty() {
        println!("vjenv: nothing to collect");
        return Ok(());
    }
    if dry_run {
        println!("vjenv: dry run, nothing removed");
        return Ok(());
    }

    if !gone.is_empty() {
        Registry::update(&app.dirs.registry(), |reg| {
            for k in &gone {
                reg.entries.remove(k);
            }
            Ok(())
        })?;
    }
    for c in &dead {
        let _ = std::fs::remove_file(c);
    }
    println!(
        "vjenv: removed {} registry {} and {} cached {}",
        gone.len(),
        if gone.len() == 1 { "entry" } else { "entries" },
        dead.len(),
        if dead.len() == 1 {
            "environment"
        } else {
            "environments"
        }
    );
    Ok(())
}
