use crate::{adb, command, model::*, wivrn};
use anyhow::{Context, Result, bail};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::{path::PathBuf, sync::Arc, time::Duration};
use tokio::sync::{Mutex, watch};

pub struct Controller {
    pub config: Config,
    pub state: watch::Sender<State>,
    pub connection: zbus::Connection,
    saved: Mutex<Saved>,
    save_path: PathBuf,
    gate: Arc<Mutex<()>>,
    cancellation: watch::Sender<u64>,
    action_epoch: watch::Sender<u64>,
}

impl Controller {
    pub async fn new(config: Config, save_path: PathBuf) -> Result<Arc<Self>> {
        let saved: Saved = match std::fs::read(&save_path) {
            Ok(data) => serde_json::from_slice(&data).context("saved_state_invalid")?,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Saved {
                preferences: Preferences {
                    auto_connect: false,
                    start_hotspot: true,
                    open_desktop: true,
                    headset_audio: true,
                },
                ..Default::default()
            },
            Err(e) => return Err(e.into()),
        };
        let (state, _) = watch::channel(State::new(&config, &saved));
        let (cancellation, _) = watch::channel(0);
        let (action_epoch, _) = watch::channel(0);
        Ok(Arc::new(Self {
            config,
            state,
            connection: zbus::Connection::session().await?,
            saved: Mutex::new(saved),
            save_path,
            gate: Arc::new(Mutex::new(())),
            cancellation,
            action_epoch,
        }))
    }

    pub fn snapshot(&self) -> State {
        self.state.borrow().clone()
    }

    pub async fn shutdown(&self) {
        if self.snapshot().operation.cancellable {
            self.cancellation.send_modify(|v| *v += 1);
        }
        let _guard = self.gate.lock().await;
        let _ = self.save().await;
    }

    fn change(&self, f: impl FnOnce(&mut State)) {
        self.state.send_modify(|s| {
            f(s);
            s.revision += 1;
        });
    }

    async fn save(&self) -> Result<()> {
        self.save_state(self.snapshot()).await
    }

    async fn save_state(&self, state: State) -> Result<()> {
        let mut saved = self.saved.lock().await;
        saved.headsets = state
            .headsets
            .into_iter()
            .filter(|h| h.status != "unauthorized")
            .collect();
        saved.selected = state.selected;
        saved.preferences = state.preferences;
        saved.session = state.session;
        saved.interrupted = state.operation.running;
        vjcommon::atomic::write(&self.save_path, &serde_json::to_vec(&*saved)?)
    }

    async fn stage(&self, stage: &str, cancellable: bool) -> Result<()> {
        self.change(|s| {
            s.operation.stage = stage.into();
            s.operation.cancellable = cancellable;
        });
        self.save().await
    }

    pub fn start_monitor(self: &Arc<Self>) {
        self.start_automation();
        let controller = self.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(3));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
            loop {
                interval.tick().await;
                let runtime = tokio::time::timeout(
                    Duration::from_secs(5),
                    wivrn::inspect(&controller.connection),
                )
                .await
                .ok()
                .and_then(Result::ok)
                .unwrap_or_default();
                let hotspot = wivrn::hotspot(&controller.config).await;
                controller.change(|s| {
                    s.runtime = runtime;
                    s.hotspot = hotspot;
                });
            }
        });
        let controller = self.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(15));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
            loop {
                interval.tick().await;
                let mut epoch = controller.action_epoch.subscribe();
                if controller.snapshot().operation.running {
                    continue;
                }
                tokio::select! {
                    _ = epoch.changed() => {},
                    result = controller.discover() => {
                        if result.is_ok() { let _ = controller.save().await; }
                    }
                }
            }
        });
    }

    fn start_automation(self: &Arc<Self>) {
        let controller = self.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(2));
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
            let mut previous = None;
            let mut previous_selected = None;
            let mut enabled = false;
            let mut connected = false;
            let mut next_attempt = tokio::time::Instant::now();
            loop {
                interval.tick().await;
                let before = controller.snapshot();
                let observed = match before.headset() {
                    Some(headset) => adb::worn(headset).await,
                    None => None,
                };
                let current = controller.snapshot();
                if current.selected != before.selected {
                    continue;
                }
                if current.selected != previous_selected {
                    previous = None;
                    previous_selected = current.selected.clone();
                    controller.change(|s| s.worn = None);
                }
                if observed == previous {
                    controller.change(|s| s.worn = observed);
                }
                if observed == Some(true) && previous != Some(true)
                    || current.preferences.auto_connect && !enabled
                {
                    next_attempt = tokio::time::Instant::now();
                }
                previous = observed;
                enabled = current.preferences.auto_connect;
                let current = controller.snapshot();
                if current.operation.running {
                    continue;
                }
                let route = current.runtime.connected
                    && current.worn == Some(true)
                    && current.preferences.headset_audio;
                let restore = !route
                    && (current.session.audio_sink.is_some()
                        || current.session.audio_source.is_some());
                let desktop = current.preferences.auto_connect
                    && current.preferences.open_desktop
                    && current.runtime.connected
                    && (!connected || !current.session.started_desktop);
                if (route && !current.session.audio_routed || restore || desktop)
                    && let Ok(_guard) = controller.gate.try_lock()
                {
                    let result = if route && !current.session.audio_routed {
                        controller.audio().await
                    } else if restore {
                        controller.restore_audio().await
                    } else {
                        Ok(())
                    };
                    if let Err(error) = result {
                        controller.change(|s| s.problem = Some(error.to_string()));
                    } else {
                        controller.change(|s| {
                            if matches!(
                                s.problem.as_deref(),
                                Some("audio_failed" | "audio_restore_failed")
                            ) {
                                s.problem = None;
                            }
                        });
                    }
                    if desktop && controller.desktop().await.is_err() {
                        controller.change(|s| s.problem = Some("desktop_failed".into()));
                    }
                    let _ = controller.save().await;
                }
                connected = current.runtime.connected;
                let current = controller.snapshot();
                if auto_start_ready(&current) && tokio::time::Instant::now() >= next_attempt {
                    next_attempt = tokio::time::Instant::now() + Duration::from_secs(30);
                    let _ = controller.submit(Request::Start).await;
                }
            }
        });
    }

    pub async fn submit(self: &Arc<Self>, request: Request) -> Result<Value> {
        match request {
            Request::Status => return Ok(serde_json::to_value(self.snapshot())?),
            Request::Cancel => {
                let state = self.snapshot();
                if !state.operation.running {
                    return Ok(serde_json::json!({"accepted": false}));
                }
                if !state.operation.cancellable {
                    bail!("not_cancellable");
                }
                if state.operation.action == "start" {
                    self.change(|s| s.preferences.auto_connect = false);
                }
                self.cancellation.send_modify(|v| *v += 1);
                return Ok(serde_json::json!({"accepted": true}));
            }
            Request::Watch => bail!("invalid_action"),
            _ => {}
        }
        if self.snapshot().operation.running {
            bail!("busy");
        }
        let guard = tokio::time::timeout(Duration::from_secs(5), self.gate.clone().lock_owned())
            .await
            .map_err(|_| anyhow::anyhow!("busy"))?;
        let mut cancel = self.cancellation.subscribe();
        let id = self.snapshot().operation.id + 1;
        self.action_epoch.send_modify(|v| *v += 1);
        self.change(|s| {
            s.problem = None;
            s.operation = Operation {
                id,
                action: request.name(),
                stage: "starting".into(),
                running: true,
                cancellable: true,
                started: now(),
                error: None,
            };
        });
        if let Err(error) = self.save().await {
            self.change(|s| {
                s.operation.running = false;
                s.operation.cancellable = false;
                s.operation.error = Some("save_failed".into());
                drop(guard);
            });
            return Err(error.context("save_failed"));
        }
        let controller = self.clone();
        let cleanup_on_error = matches!(request, Request::Start);
        tokio::spawn(async move {
            let result = tokio::select! {
                result = controller.execute(request) => result,
                _ = cancel.changed() => Err(anyhow::anyhow!("cancelled")),
            };
            if result.is_err() && cleanup_on_error && controller.snapshot().session.active {
                let _ = controller.cleanup().await;
            }
            let mut completed = controller.snapshot();
            completed.operation.running = false;
            completed.operation.cancellable = false;
            {
                let s = &mut completed;
                match result {
                    Ok(()) => s.operation.stage = "finished".into(),
                    Err(e) => {
                        let code = e.to_string();
                        s.operation.stage = if code == "cancelled" {
                            "cancelled"
                        } else {
                            "failed"
                        }
                        .into();
                        s.operation.error = Some(code);
                    }
                }
            }
            if controller.save_state(completed.clone()).await.is_err() {
                completed.problem = Some("save_failed".into());
            }
            controller.state.send_modify(|state| {
                state.operation = completed.operation;
                state.problem = completed.problem;
                state.revision += 1;
                drop(guard);
            });
        });
        Ok(serde_json::json!({"accepted": true, "id": id}))
    }

    async fn selected(&self, inventory: bool) -> Result<Headset> {
        let mut headset = self
            .snapshot()
            .headset()
            .cloned()
            .context("select_headset")?;
        if headset.status == "unauthorized" {
            bail!("unauthorized");
        }
        let serial = command::shell(&headset.endpoint, &["getprop", "ro.serialno"])
            .await
            .context("headset_unreachable")?;
        if serial.trim() != headset.serial {
            bail!("identity_mismatch");
        }
        headset.status = "device".into();
        headset.last_seen = now();
        if inventory {
            adb::inventory(&mut headset)
                .await
                .context("inventory_failed")?;
        }
        self.replace_headset(headset.clone());
        Ok(headset)
    }

    fn replace_headset(&self, headset: Headset) {
        self.change(|s| {
            if let Some(old) = s.headsets.iter_mut().find(|h| h.serial == headset.serial) {
                *old = headset;
            }
        });
    }

    async fn discover(&self) -> Result<()> {
        let wireless = self.saved.lock().await.wireless.clone();
        let present = adb::endpoints(&command::run("adb", &["devices"], 5).await?);
        for known in &wireless {
            if !present.iter().any(|(endpoint, status)| {
                endpoint == &format!("{}:5555", known.address) && status == "device"
            }) {
                let _ = adb::connect(&known.address).await;
            }
        }
        let mut headsets = adb::discover().await?;
        let missing: Vec<_> = wireless
            .iter()
            .filter(|known| {
                !headsets
                    .iter()
                    .any(|headset| headset.serial == known.serial && headset.status == "device")
            })
            .collect();
        if !missing.is_empty() {
            let mut reconnected = false;
            for address in adb::advertised().await {
                if adb::connect(&address).await.is_err() {
                    continue;
                }
                let endpoint = format!("{address}:5555");
                let serial = command::shell(&endpoint, &["getprop", "ro.serialno"])
                    .await
                    .ok();
                let matched: Vec<_> = missing
                    .iter()
                    .filter(|known| serial.as_deref().is_some_and(|s| s.trim() == known.serial))
                    .collect();
                if matched.is_empty() {
                    let _ = adb::disconnect(&address).await;
                    continue;
                }
                for known in matched {
                    if known.address != address {
                        let _ = adb::disconnect(&known.address).await;
                    }
                }
                reconnected = true;
            }
            if reconnected {
                headsets = adb::discover().await?;
            }
        }
        self.change(|s| merge_discovery(s, headsets));

        if let Some(mut headset) = self
            .snapshot()
            .headset()
            .filter(|h| h.status == "device")
            .cloned()
        {
            if headset.inventory_time.is_none() {
                adb::inventory(&mut headset).await?;
            } else {
                adb::telemetry(&mut headset).await;
            }
            if headset.transport == "wifi"
                && let Some(address) = &headset.address
                && command::local_address(address)
            {
                let mut saved = self.saved.lock().await;
                if let Some(known) = saved
                    .wireless
                    .iter_mut()
                    .find(|w| w.serial == headset.serial)
                {
                    known.address = address.clone();
                } else {
                    saved.wireless.push(Wireless {
                        serial: headset.serial.clone(),
                        address: address.clone(),
                        mac: None,
                    });
                }
            }
            self.replace_headset(headset);
        }
        Ok(())
    }

    async fn execute(&self, request: Request) -> Result<()> {
        match request {
            Request::Refresh => self.refresh().await,
            Request::Select { serial } => self.select(serial).await,
            Request::Preferences { preferences } => {
                self.change(|s| s.preferences = preferences);
                Ok(())
            }
            Request::EnableWireless => self.enable_wireless().await,
            Request::Hotspot { enabled, confirm } => self.hotspot(enabled, confirm).await,
            Request::Start => self.start().await,
            Request::Stop => self.stop().await,
            Request::Pair => self.pair().await,
            Request::Install { confirm } => self.install(confirm).await,
            Request::Launch => self.launch_headset(false).await,
            Request::Restart => self.launch_headset(true).await,
            Request::Preview => self.preview().await,
            Request::Desktop => self.desktop().await,
            Request::Audio { headset } => self.set_audio(headset).await,
            Request::Mute { muted } => self.mute(muted).await,
            Request::Updates => self.check_updates().await,
            Request::LaunchApp { package } => self.launch_app(package).await,
            Request::Forget { serial, confirm } => self.forget(serial, confirm).await,
            Request::Configure { encoder, codec } => self.configure(encoder, codec).await,
            Request::Diagnostics => self.discover().await.context("inventory_failed"),
            Request::Status | Request::Watch | Request::Cancel => bail!("invalid_action"),
        }
    }

    async fn refresh(&self) -> Result<()> {
        self.stage("reading_versions", true).await?;
        self.discover().await.context("inventory_failed")?;
        self.selected(true).await?;
        Ok(())
    }

    async fn select(&self, serial: String) -> Result<()> {
        if !self.snapshot().headsets.iter().any(|h| h.serial == serial) {
            bail!("select_headset");
        }
        self.restore_audio().await?;
        self.change(|s| {
            s.selected = Some(serial);
            s.worn = None;
        });
        Ok(())
    }

    async fn enable_wireless(&self) -> Result<()> {
        self.stage("connecting", true).await?;
        let headset = self.selected(false).await?;
        let address = adb::enable_wireless(&headset)
            .await
            .context("wireless_failed")?;
        let mac = command::shell(
            &format!("{address}:5555"),
            &["cat", "/sys/class/net/wlan0/address"],
        )
        .await
        .ok()
        .map(|s| s.trim().into());
        {
            let mut saved = self.saved.lock().await;
            saved.wireless.retain(|w| w.serial != headset.serial);
            saved.wireless.push(Wireless {
                serial: headset.serial,
                address,
                mac,
            });
        }
        self.discover().await
    }

    async fn hotspot(&self, enabled: bool, confirm: bool) -> Result<()> {
        if !enabled && self.snapshot().runtime.connected && !confirm {
            bail!("confirm_disconnect");
        }
        if enabled {
            return self.start_hotspot().await;
        }
        wivrn::service(false, "stop", &self.config.hotspot_unit)
            .await
            .context("hotspot_stop_failed")?;
        self.change(|s| s.session.started_hotspot = false);
        Ok(())
    }

    async fn stop(&self) -> Result<()> {
        self.change(|s| s.preferences.auto_connect = false);
        self.cleanup().await
    }

    async fn pair(&self) -> Result<()> {
        self.ensure_server().await?;
        let pin = wivrn::pairing(&self.connection)
            .await
            .context("pairing_failed")?;
        self.change(|s| {
            s.runtime.pin = pin;
            s.runtime.pairing = true;
        });
        let headset = self.selected(true).await?;
        let package = adb::wivrn(&headset, &self.config.apk_package).context("wivrn_missing")?;
        self.check_version(&package.version).await?;
        self.launch(&headset).await
    }

    async fn launch_headset(&self, restart: bool) -> Result<()> {
        self.ensure_server().await?;
        let headset = self.selected(true).await?;
        let package = adb::wivrn(&headset, &self.config.apk_package).context("wivrn_missing")?;
        self.check_version(&package.version).await?;
        if restart {
            command::shell(&headset.endpoint, &["am", "force-stop", &package.package])
                .await
                .context("launch_failed")?;
        }
        self.launch(&headset).await
    }

    async fn preview(&self) -> Result<()> {
        let headset = self.selected(false).await?;
        command::run(
            "systemd-run",
            &[
                "--user",
                "--collect",
                "--unit=vjvr-preview",
                "--service-type=exec",
                self.config
                    .preview_command
                    .to_str()
                    .context("preview_failed")?,
                "--serial",
                &headset.endpoint,
                "--no-audio",
                "--no-control",
                "--max-fps=30",
                "--video-bit-rate=4M",
                "--max-size=1600",
            ],
            10,
        )
        .await
        .context("preview_failed")?;
        Ok(())
    }

    async fn set_audio(&self, headset: bool) -> Result<()> {
        self.change(|s| s.preferences.headset_audio = headset);
        if headset && self.snapshot().worn == Some(true) && self.snapshot().runtime.connected {
            self.audio().await
        } else {
            self.restore_audio().await
        }
    }

    async fn mute(&self, muted: bool) -> Result<()> {
        command::run(
            "pactl",
            &[
                "set-source-mute",
                "@DEFAULT_SOURCE@",
                if muted { "1" } else { "0" },
            ],
            5,
        )
        .await
        .context("audio_failed")?;
        Ok(())
    }

    async fn check_updates(&self) -> Result<()> {
        let output = command::run(
            "curl",
            &[
                "--fail",
                "--silent",
                "--show-error",
                "--proto",
                "=https",
                "--max-time",
                "15",
                "https://api.github.com/repos/WiVRn/WiVRn/releases/latest",
            ],
            20,
        )
        .await
        .context("update_check_failed")?;
        let release: Value = serde_json::from_str(&output).context("update_check_failed")?;
        let latest = release["tag_name"]
            .as_str()
            .filter(|v| version(v).is_some())
            .context("update_check_failed")?
            .trim_start_matches('v')
            .to_string();
        self.change(|s| {
            s.latest_version = Some(latest);
            s.latest_checked = Some(now());
        });
        Ok(())
    }

    async fn launch_app(&self, package: String) -> Result<()> {
        if !command::package_id(&package) {
            bail!("invalid_package");
        }
        let headset = self.selected(false).await?;
        if !headset.software.iter().any(|s| s.package == package) {
            bail!("invalid_package");
        }
        let output = command::shell(
            &headset.endpoint,
            &[
                "monkey",
                "-p",
                &package,
                "-c",
                "android.intent.category.LAUNCHER",
                "1",
            ],
        )
        .await
        .context("app_launch_failed")?;
        if !output.contains("Events injected: 1") {
            bail!("app_launch_failed");
        }
        Ok(())
    }

    async fn forget(&self, serial: String, confirm: bool) -> Result<()> {
        if !confirm {
            bail!("confirm_forget");
        }
        if self.snapshot().runtime.connected {
            bail!("session_active");
        }
        self.saved
            .lock()
            .await
            .wireless
            .retain(|h| h.serial != serial);
        self.change(|s| {
            s.headsets.retain(|h| h.serial != serial);
            if s.selected.as_ref() == Some(&serial) {
                s.selected = None;
            }
        });
        Ok(())
    }

    async fn configure(&self, encoder: String, codec: String) -> Result<()> {
        if self.snapshot().runtime.connected {
            bail!("session_active");
        }
        self.ensure_server().await?;
        self.check_version(&self.config.server_version).await?;
        wivrn::configure(&self.connection, &encoder, &codec)
            .await
            .context("settings_failed")
    }

    async fn ensure_server(&self) -> Result<()> {
        self.stage("starting_wivrn", true).await?;
        wivrn::service(true, "start", "wivrn.service")
            .await
            .context("server_start_failed")?;
        for _ in 0..20 {
            if let Ok(runtime) = wivrn::inspect(&self.connection).await {
                self.change(|s| s.runtime = runtime);
                return Ok(());
            }
            tokio::time::sleep(Duration::from_millis(250)).await;
        }
        bail!("server_start_failed")
    }

    async fn check_version(&self, headset: &str) -> Result<()> {
        let running = wivrn::running_version()
            .await
            .context("server_unavailable")?;
        if !same_version(&running, headset) {
            bail!("version_mismatch");
        }
        Ok(())
    }

    async fn start_hotspot(&self) -> Result<()> {
        self.stage("starting_hotspot", true).await?;
        wivrn::service(false, "start", &self.config.hotspot_unit)
            .await
            .context("hotspot_start_failed")?;
        for _ in 0..30 {
            let hotspot = wivrn::hotspot(&self.config).await;
            let ready = hotspot.ready;
            self.change(|s| s.hotspot = hotspot);
            if ready {
                return Ok(());
            }
            tokio::time::sleep(Duration::from_secs(1)).await;
        }
        bail!("hotspot_start_failed")
    }

    async fn launch(&self, headset: &Headset) -> Result<()> {
        self.stage("launching_wivrn", true).await?;
        let package = adb::wivrn(headset, &self.config.apk_package).context("wivrn_missing")?;
        let address = match &headset.address {
            Some(a) => a.clone(),
            None => adb::address(&headset.endpoint).await?,
        };
        let host = wivrn::address_for(&address)
            .await
            .context("headset_unreachable")?;
        let runtime = self.snapshot().runtime;
        let pin = if runtime.pairing {
            runtime.pin.as_str()
        } else {
            ""
        };
        adb::launch(headset, &package.package, &host, pin)
            .await
            .context("launch_failed")
    }

    async fn start(&self) -> Result<()> {
        if self.snapshot().session.active && self.snapshot().runtime.connected {
            return Ok(());
        }
        let initial = self.snapshot();
        self.change(|s| s.session.active = true);
        self.save().await?;
        if initial.preferences.start_hotspot && !initial.hotspot.ready {
            self.change(|s| s.session.started_hotspot = true);
            self.save().await?;
            self.start_hotspot().await?;
        }
        if !initial.runtime.available {
            self.change(|s| s.session.started_server = true);
            self.save().await?;
        }
        self.ensure_server().await?;
        self.discover().await?;
        let headset = self.selected(true).await?;
        self.stage("checking_versions", true).await?;
        self.check_version(
            &adb::wivrn(&headset, &self.config.apk_package)
                .context("wivrn_missing")?
                .version,
        )
        .await?;
        self.launch(&headset).await?;
        self.stage("waiting_headset", true).await?;
        let deadline = tokio::time::Instant::now() + Duration::from_secs(60);
        let mut next_launch = tokio::time::Instant::now() + Duration::from_secs(3);
        while tokio::time::Instant::now() < deadline {
            let runtime = wivrn::inspect(&self.connection).await.unwrap_or_default();
            let connected = runtime.connected;
            self.change(|s| s.runtime = runtime);
            if connected {
                if initial.preferences.headset_audio
                    && self.snapshot().worn == Some(true)
                    && self.audio().await.is_err()
                {
                    self.change(|s| s.problem = Some("audio_failed".into()));
                }
                if initial.preferences.open_desktop && self.desktop().await.is_err() {
                    self.change(|s| s.problem = Some("desktop_failed".into()));
                }
                return Ok(());
            }
            if tokio::time::Instant::now() >= next_launch {
                let running =
                    command::shell(&headset.endpoint, &["pidof", &self.config.apk_package]).await;
                if running.is_err_and(|error| error.to_string() == "command_failed:adb:1") {
                    self.launch(&headset).await?;
                    self.stage("waiting_headset", true).await?;
                }
                next_launch = tokio::time::Instant::now() + Duration::from_secs(3);
            }
            tokio::time::sleep(Duration::from_secs(1)).await;
        }
        bail!("connection_timeout")
    }

    async fn audio(&self) -> Result<()> {
        let defaults = wivrn::audio_defaults().await.context("audio_failed")?;
        self.change(|s| {
            if s.session.audio_sink.is_none() {
                s.session.audio_sink = defaults.get("default_sink_name").cloned();
            }
            if s.session.audio_source.is_none() {
                s.session.audio_source = defaults.get("default_source_name").cloned();
            }
        });
        self.save().await?;
        wivrn::headset_audio().await.context("audio_failed")?;
        self.change(|s| s.session.audio_routed = true);
        Ok(())
    }

    async fn restore_audio(&self) -> Result<()> {
        let session = self.snapshot().session;
        for (action, name) in [
            ("set-default-sink", session.audio_sink),
            ("set-default-source", session.audio_source),
        ] {
            if let Some(name) = name {
                wivrn::restore_audio_device(action == "set-default-sink", &name)
                    .await
                    .context("audio_restore_failed")?;
            }
        }
        self.change(|s| {
            s.session.audio_sink = None;
            s.session.audio_source = None;
            s.session.audio_routed = false;
        });
        Ok(())
    }

    async fn desktop(&self) -> Result<()> {
        let active = command::run(
            "systemctl",
            &["--user", "is-active", "vjvr-desktop.service"],
            5,
        )
        .await
        .is_ok_and(|state| state.trim() == "active");
        if active {
            return Ok(());
        }
        self.change(|s| s.session.started_desktop = true);
        self.save().await?;
        wivrn::service(true, "start", "vjvr-desktop.service")
            .await
            .context("desktop_failed")
    }

    async fn cleanup(&self) -> Result<()> {
        self.stage("stopping_session", false).await?;
        let session = self.snapshot().session;
        let mut errors = Vec::new();
        if session.started_desktop
            && wivrn::service(true, "stop", "vjvr-desktop.service")
                .await
                .is_err()
        {
            errors.push("desktop_stop_failed");
        }
        if self.snapshot().runtime.connected && wivrn::disconnect(&self.connection).await.is_err() {
            errors.push("disconnect_failed");
        }
        if self.restore_audio().await.is_err() {
            errors.push("audio_restore_failed");
        }
        if session.started_server && wivrn::service(true, "stop", "wivrn.service").await.is_err() {
            errors.push("server_stop_failed");
        }
        if session.started_hotspot
            && wivrn::service(false, "stop", &self.config.hotspot_unit)
                .await
                .is_err()
        {
            errors.push("hotspot_stop_failed");
        }
        if errors.is_empty() {
            self.change(|s| s.session = Session::default());
        }
        self.save().await?;
        if let Some(error) = errors.first() {
            bail!("{error}");
        }
        Ok(())
    }

    async fn install(&self, confirm: bool) -> Result<()> {
        if self.snapshot().runtime.connected {
            bail!("session_active");
        }
        self.stage("checking_versions", true).await?;
        self.ensure_server().await?;
        let running = wivrn::running_version()
            .await
            .context("server_unavailable")?;
        if !same_version(&running, &self.config.server_version) {
            bail!("apk_unavailable");
        }
        let headset = self.selected(true).await?;
        let existing = headset
            .software
            .iter()
            .find(|s| s.package == self.config.apk_package);
        if existing.is_none()
            && headset
                .software
                .iter()
                .any(|s| s.package == "org.meumeu.wivrn")
            && !confirm
        {
            bail!("confirm_channel");
        }
        if let Some(existing) = existing
            && version(&existing.version) > version(&self.config.server_version)
        {
            bail!("downgrade");
        }
        self.stage("preparing_installation", true).await?;
        let path = self.config.apk.clone();
        let expected = self.config.apk_sha256.clone();
        tokio::task::spawn_blocking(move || -> Result<()> {
            use std::io::Read as _;

            let mut file = std::fs::File::open(path)?;
            let mut digest = Sha256::new();
            let mut buffer = [0u8; 64 * 1024];
            loop {
                let read = file.read(&mut buffer)?;
                if read == 0 {
                    break;
                }
                digest.update(&buffer[..read]);
            }
            if vjcommon::hex::encode(&digest.finalize()) != expected {
                bail!("apk_integrity");
            }
            Ok(())
        })
        .await
        .context("apk_integrity")?
        .context("apk_integrity")?;
        self.stage("installing", false).await?;
        let output = command::adb(
            &headset.endpoint,
            &[
                "install",
                "-r",
                self.config.apk.to_str().context("apk_unavailable")?,
            ],
            180,
        )
        .await
        .context("install_failed")?;
        if !output.lines().any(|l| l.trim() == "Success") {
            bail!("install_failed");
        }
        self.stage("verifying_installation", false).await?;
        let headset = self.selected(true).await?;
        let installed = headset
            .software
            .iter()
            .find(|s| s.package == self.config.apk_package)
            .context("install_verify_failed")?;
        if !same_version(&installed.version, &self.config.server_version) {
            bail!("install_verify_failed");
        }
        self.stage("launching_wivrn", true).await?;
        self.launch(&headset).await
    }
}

fn auto_start_ready(state: &State) -> bool {
    state.preferences.auto_connect
        && state.worn == Some(true)
        && !state.operation.running
        && !state.runtime.connected
        && state.headset().is_some_and(|h| h.status == "device")
        && !matches!(
            state.operation.error.as_deref(),
            Some(
                "version_mismatch"
                    | "wivrn_missing"
                    | "apk_unavailable"
                    | "unauthorized"
                    | "save_failed"
            )
        )
}

fn merge_discovery(state: &mut State, incoming: Vec<Headset>) {
    for old in &mut state.headsets {
        old.status = "offline".into();
    }
    for mut headset in incoming {
        if headset.model.is_empty()
            && let Some(old) = state.headsets.iter_mut().find(|old| {
                !old.model.is_empty()
                    && (old.endpoint == headset.endpoint || old.serial == headset.endpoint)
            })
        {
            if old.status != "device" {
                old.status = headset.status;
            }
            continue;
        }
        if let Some(old) = state
            .headsets
            .iter_mut()
            .find(|old| old.serial == headset.serial)
        {
            headset.software = old.software.clone();
            headset.inventory_time = old.inventory_time;
            headset.battery = old.battery;
            headset.charging = old.charging;
            headset.storage_available = old.storage_available;
            headset.storage_total = old.storage_total;
            headset.address = old.address.clone();
            *old = headset;
        } else {
            state.headsets.push(headset);
        }
    }
    let aliases: Vec<_> = state
        .headsets
        .iter()
        .filter(|h| h.model.is_empty())
        .filter_map(|alias| {
            state
                .headsets
                .iter()
                .find(|real| {
                    !real.model.is_empty()
                        && (real.endpoint == alias.endpoint || real.serial == alias.endpoint)
                })
                .map(|real| (alias.serial.clone(), real.serial.clone()))
        })
        .collect();
    for (alias, serial) in aliases {
        if state.selected.as_ref() == Some(&alias) {
            state.selected = Some(serial);
        }
        state
            .headsets
            .retain(|h| h.serial != alias || !h.model.is_empty());
    }
    if state.selected.is_none() {
        let ready: Vec<_> = state
            .headsets
            .iter()
            .filter(|h| h.status == "device")
            .collect();
        if ready.len() == 1 {
            state.selected = Some(ready[0].serial.clone());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn state() -> State {
        State::new(
            &Config {
                server_version: "26.9".into(),
                apk: PathBuf::new(),
                apk_sha256: String::new(),
                apk_package: "org.meumeu.wivrn.github".into(),
                hotspot_unit: String::new(),
                hotspot_interface: String::new(),
                hotspot_passphrase: PathBuf::new(),
                wifi_interface: String::new(),
                hostname: String::new(),
                preview_command: PathBuf::new(),
                desktop_command: PathBuf::new(),
            },
            &Saved::default(),
        )
    }

    #[test]
    fn rediscovery_merges_endpoint_alias_and_preserves_inventory_and_selection() {
        let mut state = state();
        let real = Headset {
            serial: "quest-serial".into(),
            endpoint: "192.168.1.2:5555".into(),
            model: "Quest 3".into(),
            status: "device".into(),
            ..Default::default()
        };
        let alias = Headset {
            serial: real.endpoint.clone(),
            endpoint: real.endpoint.clone(),
            status: "offline".into(),
            ..Default::default()
        };
        state.headsets = vec![alias.clone(), real.clone()];
        state.headsets[1].software.push(Software {
            version: "26.9".into(),
            ..Default::default()
        });
        state.selected = Some(alias.serial.clone());
        merge_discovery(&mut state, vec![real.clone()]);
        assert_eq!(state.headsets.len(), 1);
        assert_eq!(state.selected.as_deref(), Some("quest-serial"));
        assert_eq!(state.headsets[0].software[0].version, "26.9");
        merge_discovery(&mut state, vec![alias]);
        assert_eq!(state.headsets.len(), 1);
        assert_eq!(state.headsets[0].status, "offline");
        merge_discovery(&mut state, vec![real]);
        assert_eq!(state.headsets.len(), 1);
        assert_eq!(state.headsets[0].status, "device");
    }

    #[test]
    fn autoconnect_requires_wear_and_does_not_retry_version_errors() {
        let mut state = state();
        state.preferences.auto_connect = true;
        state.headsets.push(Headset {
            serial: "quest".into(),
            status: "device".into(),
            ..Default::default()
        });
        state.selected = Some("quest".into());
        assert!(!auto_start_ready(&state));
        state.worn = Some(false);
        assert!(!auto_start_ready(&state));
        state.worn = Some(true);
        assert!(auto_start_ready(&state));
        state.runtime.connected = true;
        assert!(!auto_start_ready(&state));
        state.runtime.connected = false;
        state.operation.error = Some("version_mismatch".into());
        assert!(!auto_start_ready(&state));
        state.operation.error = None;
        state.preferences.auto_connect = false;
        assert!(!auto_start_ready(&state));
    }
}
