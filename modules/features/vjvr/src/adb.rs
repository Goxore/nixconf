use crate::command::{self, adb, shell};
use crate::model::{Headset, Software, now};
use anyhow::{Result, bail};
use std::collections::{BTreeMap, BTreeSet};

pub fn mount_state(output: &str) -> Option<bool> {
    let header = output.split("Event log:").next()?;
    let value = |key: &str| {
        header
            .lines()
            .find_map(|line| line.trim().strip_prefix(key))
    };
    if value("Virtual proximity state: ") != Some("DISABLED")
        || value("MountWakeLock count: ") != Some("0")
    {
        return None;
    }
    match value("State: ")? {
        "HEADSET_MOUNTED" => Some(true),
        "HEADSET_UNMOUNTED" | "STANDBY" => Some(false),
        _ => None,
    }
}

pub async fn worn(headset: &Headset) -> Option<bool> {
    tokio::time::timeout(std::time::Duration::from_secs(3), async {
        let serial = shell(&headset.endpoint, &["getprop", "ro.serialno"])
            .await
            .ok()?;
        if serial.trim() != headset.serial {
            return None;
        }
        mount_state(
            &shell(&headset.endpoint, &["dumpsys", "vrpowermanager"])
                .await
                .ok()?,
        )
    })
    .await
    .ok()
    .flatten()
}

pub fn endpoints(output: &str) -> Vec<(String, String)> {
    output
        .lines()
        .filter_map(|line| {
            let mut fields = line.split_whitespace();
            let endpoint = fields.next()?;
            let state = fields.next()?;
            matches!(state, "device" | "unauthorized" | "offline")
                .then(|| (endpoint.into(), state.into()))
        })
        .collect()
}

pub async fn discover() -> Result<Vec<Headset>> {
    let list = command::run("adb", &["devices", "-l"], 5).await?;
    let mut devices = BTreeMap::<String, Headset>::new();
    for (endpoint, status) in endpoints(&list) {
        let transport = if endpoint.contains(':') {
            "wifi"
        } else {
            "usb"
        };
        if status != "device" {
            devices.insert(
                endpoint.clone(),
                Headset {
                    serial: endpoint.clone(),
                    endpoint,
                    transport: transport.into(),
                    status,
                    ..Default::default()
                },
            );
            continue;
        }
        let Ok(props) = shell(&endpoint, &["getprop"]).await else {
            continue;
        };
        let model = property(&props, "ro.product.model");
        if !model.to_lowercase().contains("quest") {
            continue;
        }
        let serial = property(&props, "ro.serialno");
        if serial.is_empty() {
            continue;
        }
        let headset = Headset {
            serial: serial.clone(),
            endpoint,
            model,
            transport: transport.into(),
            status: "device".into(),
            android: property(&props, "ro.build.version.release"),
            os_build: property(&props, "ro.build.display.id"),
            last_seen: now(),
            ..Default::default()
        };
        if devices.get(&serial).is_none_or(|h| h.transport == "usb") {
            devices.insert(serial, headset);
        }
    }
    Ok(devices.into_values().collect())
}

fn property(output: &str, key: &str) -> String {
    let prefix = format!("[{key}]: [");
    output
        .lines()
        .find_map(|line| line.strip_prefix(&prefix)?.strip_suffix(']'))
        .unwrap_or_default()
        .into()
}

pub fn packages(output: &str) -> Vec<Software> {
    let mut apps = BTreeMap::new();
    let mut current: Option<Software> = None;
    for line in output.lines().map(str::trim) {
        if let Some(rest) = line.strip_prefix("Package [") {
            if let Some(app) = current.take().filter(|a| !a.version.is_empty()) {
                apps.insert(app.package.clone(), app);
            }
            current = rest
                .split_once(']')
                .filter(|(id, _)| command::package_id(id))
                .map(|(id, _)| Software {
                    package: id.into(),
                    source: source(id).into(),
                    ..Default::default()
                });
        } else if let Some(app) = &mut current {
            if let Some(value) = line.strip_prefix("versionName=") {
                app.version = value.into();
            }
            if let Some(value) = line.strip_prefix("versionCode=") {
                app.version_code = value
                    .split_whitespace()
                    .next()
                    .and_then(|v| v.parse().ok())
                    .unwrap_or_default();
            }
        }
    }
    if let Some(app) = current.filter(|a| !a.version.is_empty()) {
        apps.insert(app.package.clone(), app);
    }
    apps.into_values().collect()
}

fn source(package: &str) -> &str {
    match package {
        "org.meumeu.wivrn" => "meta",
        "org.meumeu.wivrn.github" => "github",
        p if p.starts_with("org.meumeu.wivrn.") => "custom",
        _ => "unknown",
    }
}

pub async fn inventory(headset: &mut Headset) -> Result<()> {
    let output = shell(&headset.endpoint, &["dumpsys", "package", "packages"]).await?;
    let user = shell(&headset.endpoint, &["pm", "list", "packages", "-3"]).await?;
    let ids: Vec<_> = user
        .lines()
        .filter_map(|l| l.trim().strip_prefix("package:"))
        .collect();
    headset.software = packages(&output)
        .into_iter()
        .filter(|p| ids.contains(&p.package.as_str()) || p.package.starts_with("org.meumeu.wivrn"))
        .collect();
    headset.inventory_time = Some(now());
    telemetry(headset).await;
    Ok(())
}

pub async fn telemetry(headset: &mut Headset) {
    if let Ok(out) = shell(&headset.endpoint, &["dumpsys", "battery"]).await {
        for line in out.lines().map(str::trim) {
            if let Some(value) = line.strip_prefix("level:") {
                headset.battery = value.trim().parse().ok();
            }
            if let Some(value) = line.strip_prefix("status:") {
                headset.charging = matches!(value.trim(), "2" | "5");
            }
        }
    }
    if let Ok(out) = shell(&headset.endpoint, &["df", "-k", "/data"]).await
        && let Some(line) = out.lines().nth(1)
    {
        let fields: Vec<_> = line.split_whitespace().collect();
        headset.storage_total = fields
            .get(1)
            .and_then(|s| s.parse::<u64>().ok())
            .map(|v| v * 1024);
        headset.storage_available = fields
            .get(3)
            .and_then(|s| s.parse::<u64>().ok())
            .map(|v| v * 1024);
    }
    headset.address = address(&headset.endpoint).await.ok();
}

pub async fn address(endpoint: &str) -> Result<String> {
    let out = shell(endpoint, &["ip", "-o", "-4", "addr", "show", "wlan0"]).await?;
    for word in out.split_whitespace() {
        if let Some((ip, _)) = word.split_once('/')
            && command::local_address(ip)
        {
            return Ok(ip.into());
        }
    }
    bail!("no_wifi_address")
}

pub async fn enable_wireless(headset: &Headset) -> Result<String> {
    let ip = address(&headset.endpoint).await?;
    if headset.transport != "wifi" {
        adb(&headset.endpoint, &["tcpip", "5555"], 10).await?;
    }
    let endpoint = format!("{ip}:5555");
    for _ in 0..10 {
        let _ = connect(&ip).await;
        if let Ok(serial) = shell(&endpoint, &["getprop", "ro.serialno"]).await {
            if serial.trim() != headset.serial {
                bail!("identity_mismatch");
            }
            return Ok(ip);
        }
        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
    }
    bail!("wireless_failed")
}

pub async fn connect(address: &str) -> Result<()> {
    if !command::local_address(address) {
        bail!("invalid_address");
    }
    let output = command::run("adb", &["connect", &format!("{address}:5555")], 5).await?;
    if !output.contains("connected to") {
        bail!("headset_unreachable");
    }
    Ok(())
}

pub async fn disconnect(address: &str) -> Result<()> {
    if !command::local_address(address) {
        bail!("invalid_address");
    }
    command::run("adb", &["disconnect", &format!("{address}:5555")], 5).await?;
    Ok(())
}

pub async fn advertised() -> Vec<String> {
    let Ok(output) = command::run("avahi-browse", &["-rtp", "_adb._tcp"], 8).await else {
        return Vec::new();
    };
    advertised_addresses(&output)
}

fn advertised_addresses(output: &str) -> Vec<String> {
    output
        .lines()
        .filter_map(|line| {
            let fields: Vec<_> = line.split(';').collect();
            (fields.len() >= 9
                && fields[0] == "="
                && fields[2] == "IPv4"
                && fields[4] == "_adb._tcp"
                && fields[8] == "5555"
                && command::local_address(fields[7]))
            .then(|| fields[7].to_owned())
        })
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

pub fn wivrn<'a>(headset: &'a Headset, managed: &str) -> Option<&'a Software> {
    headset
        .software
        .iter()
        .find(|p| p.package == managed)
        .or_else(|| {
            headset
                .software
                .iter()
                .find(|p| p.package == "org.meumeu.wivrn")
        })
}

pub async fn launch(headset: &Headset, package: &str, address: &str, pin: &str) -> Result<()> {
    if !command::package_id(package) || !command::local_address(address) {
        bail!("invalid_launch");
    }
    let uri = connection_uri(address, pin)?;
    let out = shell(
        &headset.endpoint,
        &[
            "am",
            "start",
            "-a",
            "android.intent.action.VIEW",
            "-d",
            &uri,
            package,
        ],
    )
    .await?;
    if out.contains("Error:") || out.contains("Exception") {
        bail!("launch_failed");
    }
    Ok(())
}

fn connection_uri(address: &str, pin: &str) -> Result<String> {
    if !command::local_address(address)
        || (!pin.is_empty() && (pin.len() != 6 || !pin.bytes().all(|b| b.is_ascii_digit())))
    {
        bail!("invalid_launch");
    }
    Ok(if pin.is_empty() {
        format!("wivrn://{address}:9757")
    } else {
        format!("wivrn://:{pin}@{address}:9757")
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mount_state_uses_current_sensor_state_and_rejects_overrides() {
        let header = "Virtual proximity state: DISABLED\nMountWakeLock count: 0\nState: ";
        assert_eq!(
            mount_state(&format!(
                "{header}HEADSET_MOUNTED\nEvent log:\nState: STANDBY"
            )),
            Some(true)
        );
        assert_eq!(
            mount_state(&format!(
                "{header}HEADSET_UNMOUNTED\nEvent log:\nState: HEADSET_MOUNTED"
            )),
            Some(false)
        );
        assert_eq!(mount_state(&format!("{header}STANDBY")), Some(false));
        assert_eq!(mount_state(&format!("{header}WARM_UP")), None);
        assert_eq!(
            mount_state(&format!("{header}HEADSET_MOUNTED").replace("DISABLED", "ENABLED")),
            None
        );
        assert_eq!(
            mount_state(&format!("{header}HEADSET_MOUNTED").replace("count: 0", "count: 1")),
            None
        );
        assert_eq!(mount_state("Can't find service: vrpowermanager"), None);
    }

    #[test]
    fn pairing_uri_accepts_only_a_local_address_and_six_digit_pin() {
        assert_eq!(
            connection_uri("192.168.1.2", "123456").unwrap(),
            "wivrn://:123456@192.168.1.2:9757"
        );
        assert_eq!(
            connection_uri("192.168.1.2", "").unwrap(),
            "wivrn://192.168.1.2:9757"
        );
        assert!(connection_uri("192.168.1.2", "12345@").is_err());
        assert!(connection_uri("example.com", "123456").is_err());
    }

    #[test]
    fn inventory_tracks_versions_and_distinct_install_channels() {
        let input = "Packages:\n  Package [org.meumeu.wivrn.github] (a):\n    versionCode=260900\n    versionName=26.9\n  Package [org.meumeu.wivrn] (b):\n    versionCode=260602 minSdk=29\n    versionName=26.6.2\n";
        let apps = packages(input);
        assert_eq!(apps.len(), 2);
        assert_eq!(apps[0].source, "meta");
        assert_eq!(apps[1].version, "26.9");
        assert_eq!(apps[1].version_code, 260900);
    }

    #[test]
    fn discovery_does_not_treat_daemon_messages_as_devices() {
        let devices = endpoints(
            "* daemon started successfully\nList of devices attached\nABC unauthorized\n192.168.12.2:5555 device product:hollywood\n",
        );
        assert_eq!(devices.len(), 2);
        assert_eq!(devices[0].1, "unauthorized");
    }

    #[test]
    fn advertised_adb_addresses_ignore_unresolved_and_unrelated_services() {
        let records = "+;ap0;IPv4;quest;_adb._tcp;local\n=;ap0;IPv4;quest;_adb._tcp;local;Android.local;192.168.12.193;5555;\n=;enp14s0;IPv4;quest;_adb._tcp;local;Android.local;192.168.12.193;5555;\n=;enp14s0;IPv4;other;_adb._tcp;local;Android.local;8.8.8.8;5555;\n=;enp14s0;IPv4;other;_adb._tcp;local;Android.local;192.168.1.2;37099;\n";
        assert_eq!(advertised_addresses(records), vec!["192.168.12.193"]);
    }
}
