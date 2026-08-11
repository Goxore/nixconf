mod config;
mod devshell;
mod emit;
mod identity;
mod paths;
mod prompt;
mod registry;
mod root;
mod shellinit;

use anyhow::{bail, Context as _, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::Shell as CompletionShell;
use config::Config;
use emit::{render, EnvOp, Shell};
use paths::Dirs;
use registry::{Registry, ENV_ALLOW, ENV_DENY};
use root::{RealFs, RootKind};
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
    Resolve,
    Env {
        #[arg(value_name = "SHELL", default_value = "posix")]
        shell: String,
        #[arg(long)]
        no_devshell: bool,
    },
    Tool {
        #[arg(value_name = "TOOL")]
        tool: String,
    },
    Assign {
        #[arg(long, value_name = "NAME")]
        identity: Option<String>,
        #[arg(long, value_name = "TOOL=ACCOUNT")]
        tool: Vec<String>,
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
    system: String,
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
        Ok(Self {
            dirs,
            config,
            registry,
            cwd,
            system: std::env::var("VJENV_SYSTEM").unwrap_or_else(|_| "x86_64-linux".into()),
        })
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
        if let Some(o) = std::env::var("VJENV_OVERRIDE").ok().filter(|v| !v.is_empty()) {
            return (Some(o), true);
        }
        let id = root
            .and_then(|r| self.registry.get(r))
            .and_then(|e| e.identity.clone());
        (id, false)
    }

    fn env_ops(&self) -> Vec<EnvOp> {
        let root = self.root().map(|(r, _)| r);
        let (id, pinned) = self.identity_of(root.as_deref());
        let resolved = id
            .as_deref()
            .and_then(|i| self.config.identity(i).map(|d| (i, d)));
        let jj_current = std::env::var("JJ_CONFIG").ok();

        identity::env_ops(&identity::Context {
            dirs: &self.dirs,
            root: root.as_deref(),
            id: resolved.map(|(i, _)| i),
            identity: resolved.map(|(_, d)| d),
            pinned,
            jj_config_current: jj_current.as_deref(),
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

    fn project(&self) -> Option<devshell::Project> {
        devshell::find(&self.cwd, &self.dirs.home)
    }

    fn require_project(&self) -> Result<devshell::Project> {
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
        }
    }

    fn chosen_shell(&self, project: &devshell::Project) -> Option<String> {
        self.registry
            .get(&project.dir)
            .and_then(|e| e.shell.clone())
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
        Command::Resolve => {
            println!("{}", app.require_root()?.display());
            Ok(())
        }
        Command::Env { shell, no_devshell } => env(&app, &shell, no_devshell),
        Command::Tool { tool } => tool_env(&app, &tool),
        Command::Assign { identity, tool } => assign(&app, identity, tool),
        Command::Use {
            identity,
            clear,
            shell,
        } => use_identity(&app, identity, clear, &shell),
        Command::Exec { argv } => exec(&app, argv),
        Command::Shells => {
            for s in app.require_project()?.shells(&app.system)? {
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
            let gated = std::env::var(shellinit::GATED_DIR_VAR)
                .ok()
                .filter(|v| !v.is_empty());
            print!("{}", shellinit::fish(&exe, gated.as_deref()));
            Ok(())
        }
    }
}

fn env(app: &App, shell: &str, no_devshell: bool) -> Result<()> {
    let shell = Shell::parse(shell)
        .with_context(|| format!("unknown shell '{shell}' (want fish or posix)"))?;

    let ops = app.env_ops();
    if let Some(id) = active_identity(&ops) {
        app.sync_jj_fragment(&id)?;
    }

    let mut text = render(&ops, shell);
    if shell == Shell::Fish && !no_devshell {
        text.push_str(&devshell_section(app));
    }

    let mut out = std::io::stdout().lock();
    out.write_all(text.as_bytes())?;
    Ok(())
}

fn active_identity(ops: &[EnvOp]) -> Option<String> {
    ops.iter().find_map(|o| match o {
        EnvOp::Set(n, v) if n == "VJENV_IDENTITY" => Some(v.clone()),
        _ => None,
    })
}

fn devshell_section(app: &App) -> String {
    let current = std::env::var("VJENV_ENV_ROOT").ok().filter(|v| !v.is_empty());
    let unload = "__vjenv_env_unload\n";

    let Some(project) = app.project() else {
        return if current.is_some() { unload.into() } else { String::new() };
    };

    let state = app.registry.get(&project.dir).and_then(|e| e.env.clone());
    if state.as_deref() != Some(ENV_ALLOW) {
        let mut out = String::new();
        if current.is_some() {
            out.push_str(unload);
        }
        if state.as_deref() != Some(ENV_DENY) {
            out.push_str(&format!(
                "set -g __vjenv_env_pending {}\n",
                emit::quote(&project.dir.to_string_lossy(), Shell::Fish)
            ));
        }
        return out;
    }

    if current.as_deref() == Some(project.dir.to_string_lossy().as_ref()) {
        return String::new();
    }

    let dev = match app.loader().load(&project, app.chosen_shell(&project).as_deref()) {
        Ok(d) => d,
        Err(e) => {
            eprintln!("vjenv: {e:#}");
            return if current.is_some() { unload.into() } else { String::new() };
        }
    };

    let mut out = String::new();
    out.push_str(unload);
    out.push_str("set -g __vjenv_env_names\nset -g __vjenv_env_olds\nset -g __vjenv_env_oldpath $PATH\n");
    for (k, v) in &dev.vars {
        out.push_str(&format!(
            "__vjenv_env_set {k} {}\n",
            emit::quote(v, Shell::Fish)
        ));
    }
    if !dev.path.is_empty() {
        let args: Vec<String> = dev
            .path
            .iter()
            .map(|p| emit::quote(p, Shell::Fish))
            .collect();
        out.push_str(&format!("__vjenv_env_path {}\n", args.join(" ")));
    }
    out.push_str(&format!(
        "set -gx VJENV_ENV_ROOT {}\n",
        emit::quote(&project.dir.to_string_lossy(), Shell::Fish)
    ));
    out
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
                    "", app.dirs.identity_toml().display()
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

    let entry = app.registry.get(&root);
    for tool in app.config.accounts.keys() {
        let line = match (&id, entry.and_then(|e| e.tool(tool))) {
            (None, _) => "locked — off PATH until this project has an identity".to_string(),
            (Some(_), Some(a)) => a.to_string(),
            (Some(_), None) => format!(
                "unassigned — asked on first run, from [{}]",
                app.config.accounts_for(tool).join(", ")
            ),
        };
        println!("{tool:<9}: {line}");
    }
    env_status(app);
    Ok(())
}

fn env_status(app: &App) {
    let Some(project) = app.project() else { return };
    let mut state = match app.registry.get(&project.dir).and_then(|e| e.env.as_deref()) {
        Some(s) => s.to_string(),
        None => "not allowed yet (asked on entry)".into(),
    };
    if let Some(which) = app.chosen_shell(&project) {
        state = format!("{state}, devShell {which}");
    }
    println!("{:<9}: {} [{state}]", "env", project.dir.display());
    if let Ok(loaded) = std::env::var("VJENV_ENV_ROOT") {
        println!("{:<9}: {loaded}", "loaded");
    }
}

fn assign(app: &App, identity: Option<String>, tools: Vec<String>) -> Result<()> {
    let root = app.require_root()?;

    if let Some(id) = &identity {
        if !app.config.identities.contains_key(id) {
            bail!(
                "no such identity '{id}' — declared: [{}]",
                app.config.identity_names().join(", ")
            );
        }
    }

    let mut parsed: Vec<(String, String)> = Vec::new();
    for spec in &tools {
        let (tool, account) = spec
            .split_once('=')
            .with_context(|| format!("--tool wants TOOL=ACCOUNT, got '{spec}'"))?;
        check_account(app, tool, account)?;
        parsed.push((tool.to_string(), account.to_string()));
    }

    Registry::update(&app.dirs.registry(), |reg| {
        let entry = reg.entry_mut(&root);
        if let Some(id) = identity {
            entry.identity = Some(id);
        }
        for (tool, account) in parsed {
            entry.tools.insert(tool, account);
        }
        Ok(())
    })?;

    status(&App::load(Some(root))?)
}

fn check_account(app: &App, tool: &str, account: &str) -> Result<()> {
    let known = app.config.accounts_for(tool);
    if known.is_empty() {
        bail!(
            "no {tool} accounts declared in {}",
            app.dirs.identity_toml().display()
        );
    }
    if !known.iter().any(|a| a == account) {
        bail!(
            "no {tool} account named '{account}' — declared: [{}]",
            known.join(", ")
        );
    }
    Ok(())
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

fn resolve_identity(app: &App, root: &Path) -> Result<String> {
    if let (Some(id), _) = app.identity_of(Some(root)) {
        if !app.config.identities.contains_key(&id) {
            bail!(
                "'{id}' is assigned to {} but is not declared in {}",
                root.display(),
                app.dirs.identity_toml().display()
            );
        }
        return Ok(id);
    }

    let names = app.config.identity_names();
    if names.is_empty() {
        bail!(
            "no identities declared in {}",
            app.dirs.identity_toml().display()
        );
    }
    let chosen = prompt::pick(&format!("which identity owns {}?", root.display()), &names)
        .with_context(|| {
            format!(
                "{} has no identity and there is no terminal to ask on\n       \
                 run: vjenv assign --identity <name>",
                root.display()
            )
        })?
        .to_string();

    Registry::update(&app.dirs.registry(), |reg| {
        reg.entry_mut(root).identity = Some(chosen.clone());
        Ok(())
    })?;
    Ok(chosen)
}

fn resolve_account(app: &App, root: &Path, tool: &str) -> Result<String> {
    let recorded = app
        .registry
        .get(root)
        .and_then(|e| e.tool(tool))
        .filter(|a| app.config.accounts_for(tool).iter().any(|k| k == a))
        .map(str::to_string);
    if let Some(a) = recorded {
        return Ok(a);
    }

    let accounts = app.config.accounts_for(tool);
    let chosen = match accounts {
        [] => bail!(
            "no {tool} accounts declared in {}",
            app.dirs.identity_toml().display()
        ),
        [only] => only.clone(),
        many => {
            let names: Vec<&str> = many.iter().map(String::as_str).collect();
            prompt::pick(&format!("which {tool} account for {}?", root.display()), &names)
                .with_context(|| {
                    format!(
                        "{} has no {tool} account and there is no terminal to ask on\n       \
                         run: vjenv assign --tool {tool}=<name>",
                        root.display()
                    )
                })?
                .to_string()
        }
    };

    Registry::update(&app.dirs.registry(), |reg| {
        reg.entry_mut(root).tools.insert(tool.into(), chosen.clone());
        Ok(())
    })?;
    Ok(chosen)
}

fn tool_env(app: &App, tool: &str) -> Result<()> {
    if app.config.accounts_for(tool).is_empty() {
        bail!(
            "no {tool} accounts declared in {}",
            app.dirs.identity_toml().display()
        );
    }
    let root = app.require_root()?;
    let id = resolve_identity(app, &root)?;
    let account = resolve_account(app, &root, tool)?;

    let home = app.dirs.tool_home(tool, &account);
    std::fs::create_dir_all(&home)
        .with_context(|| format!("cannot create {}", home.display()))?;
    write_instructions(app, &id, &home, tool)?;

    let app = App::load(Some(root))?;
    let mut ops = app.env_ops();
    if let Some(id) = active_identity(&ops) {
        app.sync_jj_fragment(&id)?;
    }
    ops.push(EnvOp::set(
        match tool {
            "claude" => "CLAUDE_CONFIG_DIR",
            "codex" => "CODEX_HOME",
            _ => bail!("don't know which variable configures {tool}"),
        },
        home.to_string_lossy(),
    ));
    print!("{}", render(&ops, Shell::Posix));
    Ok(())
}

fn write_instructions(app: &App, id: &str, home: &Path, tool: &str) -> Result<()> {
    let name = if tool == "codex" { "AGENTS.md" } else { "CLAUDE.md" };
    let parts = [
        app.dirs.config.join("AGENTS.md"),
        app.dirs.config.join(format!("identities/{id}.md")),
    ];

    let mut body = String::new();
    for part in parts.iter().filter(|p| p.is_file()) {
        let text = std::fs::read_to_string(part)
            .with_context(|| format!("cannot read {}", part.display()))?;
        if !body.is_empty() && !body.ends_with('\n') {
            body.push('\n');
        }
        body.push_str(&text);
    }
    if body.is_empty() {
        return Ok(());
    }
    paths::atomic_write(&home.join(name), body.as_bytes())
}

fn exec(app: &App, argv: Vec<String>) -> Result<()> {
    use std::os::unix::process::CommandExt;

    let mut ops = app.env_ops();
    if let Some(id) = active_identity(&ops) {
        app.sync_jj_fragment(&id)?;
    }

    let mut path = std::env::var("PATH").unwrap_or_default();
    if let Some(project) = app.project() {
        if app.registry.get(&project.dir).and_then(|e| e.env.as_deref()) == Some(ENV_ALLOW) {
            if let Ok(dev) = app.loader().load(&project, app.chosen_shell(&project).as_deref()) {
                ops.extend(dev.ops());
                if !dev.path.is_empty() {
                    path = format!("{}:{path}", dev.path.join(":"));
                }
            }
        }
    }
    if active_identity(&ops).is_some() {
        if let Ok(gated) = std::env::var(shellinit::GATED_DIR_VAR) {
            if !gated.is_empty() {
                path = format!("{gated}:{path}");
            }
        }
    }

    let mut cmd = std::process::Command::new(&argv[0]);
    cmd.args(&argv[1..]).env("PATH", path);
    for op in &ops {
        match op {
            EnvOp::Set(k, v) => {
                cmd.env(k, v);
            }
            EnvOp::Unset(k) => {
                cmd.env_remove(k);
            }
        }
    }
    Err(anyhow::Error::from(cmd.exec()).context(format!("cannot run {}", argv[0])))
}

fn gate(app: &App, verdict: &str, devshell: Option<String>) -> Result<()> {
    let project = app.require_project()?;
    let devshell = devshell.filter(|d| !d.is_empty());
    Registry::update(&app.dirs.registry(), |reg| {
        let entry = reg.entry_mut(&project.dir);
        entry.env = Some(verdict.into());
        if verdict == ENV_ALLOW {
            if let Some(name) = devshell.clone() {
                entry.shell = Some(name);
            }
        }
        Ok(())
    })?;
    match devshell {
        Some(name) if verdict == ENV_ALLOW => {
            println!("vjenv: {} marked allow, devShell {name}", project.dir.display())
        }
        _ => println!("vjenv: {} marked {verdict}", project.dir.display()),
    }
    Ok(())
}

fn reload(app: &App) -> Result<()> {
    let project = app.require_project()?;
    app.loader()
        .forget(&project, app.chosen_shell(&project).as_deref())?;
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

    let mut dead_caches = Vec::new();
    if let Ok(entries) = std::fs::read_dir(app.dirs.devshell()) {
        for e in entries.flatten() {
            let path = e.path();
            if path.extension().is_none_or(|x| x != "env") {
                continue;
            }
            let key = path.file_stem().unwrap_or_default().to_string_lossy().into_owned();
            let profile = app.dirs.profiles().join(&key);
            if !profile.canonicalize().is_ok_and(|p| p.exists()) {
                dead_caches.push(path);
            }
        }
    }

    for k in &gone {
        println!("registry: {k}");
    }
    for c in &dead_caches {
        println!("cache   : {}", c.display());
    }
    if gone.is_empty() && dead_caches.is_empty() {
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
    for c in &dead_caches {
        let _ = std::fs::remove_file(c);
    }
    println!(
        "vjenv: removed {} registry {} and {} cached {}",
        gone.len(),
        if gone.len() == 1 { "entry" } else { "entries" },
        dead_caches.len(),
        if dead_caches.len() == 1 { "environment" } else { "environments" }
    );
    Ok(())
}
