use crate::command;
use crate::model::{Config, Hotspot, Runtime};
use anyhow::{Result, bail};
use serde_json::Value;
use std::collections::HashMap;
use zbus::{Connection, Proxy};

pub async fn proxy(connection: &Connection) -> Result<Proxy<'_>> {
    Ok(Proxy::new(
        connection,
        "io.github.wivrn.Server",
        "/io/github/wivrn/Server",
        "io.github.wivrn.Server",
    )
    .await?)
}

pub async fn inspect(connection: &Connection) -> Result<Runtime> {
    let p = proxy(connection).await?;
    let connected: bool = p.get_property("HeadsetConnected").await?;
    let (session, name, bitrate, rate, codecs, pairing, pin, config) = tokio::join!(
        p.get_property::<bool>("SessionRunning"),
        p.get_property::<String>("SystemName"),
        p.get_property::<u32>("Bitrate"),
        p.get_property::<f64>("PreferredRefreshRate"),
        p.get_property::<Vec<String>>("SupportedCodecs"),
        p.get_property::<bool>("PairingEnabled"),
        p.get_property::<String>("Pin"),
        p.get_property::<String>("JsonConfiguration")
    );
    Ok(Runtime {
        available: true,
        connected,
        session_running: session.unwrap_or(false),
        headset_name: name.unwrap_or_default(),
        bitrate: bitrate.unwrap_or_default(),
        refresh_rate: rate.unwrap_or_default(),
        codecs: codecs.unwrap_or_default(),
        pairing: pairing.unwrap_or(false),
        pin: pin.unwrap_or_default(),
        configuration: serde_json::from_str(&config.unwrap_or_default()).unwrap_or(Value::Null),
        version: running_version().await,
    })
}

pub async fn running_version() -> Option<String> {
    let pid = command::run(
        "systemctl",
        &[
            "--user",
            "show",
            "wivrn.service",
            "--property=MainPID",
            "--value",
        ],
        3,
    )
    .await
    .ok()?;
    let pid: u32 = pid.trim().parse().ok()?;
    if pid == 0 {
        return None;
    }
    let exe = tokio::fs::read_link(format!("/proc/{pid}/exe"))
        .await
        .ok()?;
    let path = exe.to_string_lossy();
    let version = path.split("-wivrn-").nth(1)?.split('/').next()?;
    crate::model::version(version).map(|_| version.into())
}

pub async fn pairing(connection: &Connection) -> Result<String> {
    Ok(proxy(connection)
        .await?
        .call("EnablePairing", &(120_i32,))
        .await?)
}

pub async fn disconnect(connection: &Connection) -> Result<()> {
    Ok(proxy(connection).await?.call("Disconnect", &()).await?)
}

pub async fn configure(connection: &Connection, encoder: &str, codec: &str) -> Result<()> {
    if !matches!(encoder, "auto" | "vulkan" | "vaapi" | "x264")
        || !matches!(codec, "auto" | "h264" | "h265" | "av1")
    {
        bail!("unsupported_settings");
    }
    if (encoder == "vulkan" && codec == "av1")
        || (encoder == "x264" && !matches!(codec, "h264" | "auto"))
    {
        bail!("unsupported_settings");
    }
    let p = proxy(connection).await?;
    let current: String = p.get_property("JsonConfiguration").await?;
    let mut config: Value =
        serde_json::from_str(&current).unwrap_or_else(|_| serde_json::json!({}));
    let object = config
        .as_object_mut()
        .ok_or_else(|| anyhow::anyhow!("invalid_settings"))?;
    if encoder == "auto" && codec == "auto" {
        object.remove("encoder");
    } else {
        let mut settings = serde_json::Map::new();
        if encoder != "auto" {
            settings.insert("encoder".into(), encoder.into());
        }
        if codec != "auto" {
            settings.insert("codec".into(), codec.into());
        }
        object.insert("encoder".into(), settings.into());
    }
    p.set_property("JsonConfiguration", config.to_string())
        .await?;
    Ok(())
}

pub async fn service(user: bool, action: &str, unit: &str) -> Result<()> {
    if !matches!(action, "start" | "stop" | "restart" | "reset-failed") {
        bail!("invalid_action");
    }
    let mut args = vec!["--no-ask-password"];
    if user {
        args.push("--user");
    }
    args.extend([action, unit]);
    command::run("systemctl", &args, 45).await?;
    Ok(())
}

pub async fn unit_state(unit: &str) -> String {
    command::run(
        "systemctl",
        &["show", unit, "--property=ActiveState", "--value"],
        3,
    )
    .await
    .unwrap_or_else(|_| "unavailable".into())
    .trim()
    .into()
}

pub async fn hotspot(config: &Config) -> Hotspot {
    let interface = config.hotspot_interface.as_str();
    let state = unit_state(&config.hotspot_unit).await;
    let mut hotspot = Hotspot {
        state,
        passphrase: tokio::fs::read_to_string(&config.hotspot_passphrase)
            .await
            .ok()
            .map(|p| p.trim().to_string())
            .filter(|p| !p.is_empty()),
        ..Default::default()
    };
    if let Ok(out) = command::run("ip", &["-j", "-4", "address", "show", "dev", interface], 3).await
        && let Ok(json) = serde_json::from_str::<Value>(&out)
    {
        hotspot.address = json[0]["addr_info"].as_array().and_then(|a| {
            a.iter()
                .find_map(|a| a["local"].as_str().map(str::to_string))
        });
    }
    if let Ok(out) = command::run("iw", &["dev", interface, "info"], 3).await {
        for line in out.lines().map(str::trim) {
            if let Some(ssid) = line.strip_prefix("ssid ") {
                hotspot.ssid = Some(ssid.into());
            }
            if let Some(channel) = line.strip_prefix("channel ") {
                hotspot.channel = channel
                    .split_whitespace()
                    .next()
                    .and_then(|v| v.parse().ok());
                hotspot.width = channel
                    .split("width: ")
                    .nth(1)
                    .and_then(|v| v.split_whitespace().next())
                    .and_then(|v| v.parse().ok());
            }
        }
    }
    hotspot.ready =
        hotspot.state == "active" && hotspot.address.is_some() && hotspot.ssid.is_some();
    hotspot
}

pub async fn address_for(headset: &str) -> Result<String> {
    if !command::local_address(headset) {
        bail!("invalid_address");
    }
    let out = command::run("ip", &["-j", "route", "get", headset], 3).await?;
    let value: Value = serde_json::from_str(&out)?;
    let source = value[0]["prefsrc"]
        .as_str()
        .ok_or_else(|| anyhow::anyhow!("no_route"))?;
    if !command::local_address(source) {
        bail!("no_route");
    }
    Ok(source.into())
}

pub async fn paired(connection: &Connection) -> Result<Vec<(String, String, i64)>> {
    Ok(proxy(connection).await?.get_property("KnownKeys").await?)
}

pub async fn revoke(connection: &Connection, key: &str) -> Result<()> {
    Ok(proxy(connection).await?.call("RevokeKey", &(key,)).await?)
}

pub async fn audio_defaults() -> Result<HashMap<String, String>> {
    let out = command::run("pactl", &["--format=json", "info"], 5).await?;
    let info: Value = serde_json::from_str(&out)?;
    let mut defaults = HashMap::new();
    for name in ["default_sink_name", "default_source_name"] {
        if let Some(value) = info[name].as_str() {
            defaults.insert(name.into(), value.into());
        }
    }
    Ok(defaults)
}

pub async fn headset_audio() -> Result<()> {
    for playback in [true, false] {
        let nodes = audio_nodes(playback).await?;
        let name = nodes
            .iter()
            .find(|node| {
                vr_audio(node)
                    && (playback
                        || !node["name"]
                            .as_str()
                            .unwrap_or_default()
                            .ends_with(".monitor"))
            })
            .and_then(|node| node["name"].as_str());
        if let Some(name) = name {
            let defaults = audio_defaults().await?;
            let old = defaults.get(if playback {
                "default_sink_name"
            } else {
                "default_source_name"
            });
            route_audio(playback, name, old.map(String::as_str)).await?;
        } else if playback {
            bail!("headset_audio_missing");
        }
    }
    Ok(())
}

async fn audio_nodes(playback: bool) -> Result<Vec<Value>> {
    let output = command::run(
        "pactl",
        &[
            "--format=json",
            "list",
            if playback { "sinks" } else { "sources" },
        ],
        5,
    )
    .await?;
    Ok(serde_json::from_str(&output)?)
}

fn vr_audio(node: &Value) -> bool {
    node["name"]
        .as_str()
        .is_some_and(|name| name.to_lowercase().contains("wivrn"))
        || node["description"]
            .as_str()
            .is_some_and(|name| name.to_lowercase().contains("wivrn"))
}

async fn route_audio(playback: bool, target: &str, from: Option<&str>) -> Result<()> {
    let nodes = audio_nodes(playback).await?;
    let old_index = from
        .and_then(|name| {
            nodes
                .iter()
                .find(|node| node["name"].as_str() == Some(name))
        })
        .and_then(|node| node["index"].as_u64());
    let output = command::run(
        "pactl",
        &[
            "--format=json",
            "list",
            if playback {
                "sink-inputs"
            } else {
                "source-outputs"
            },
        ],
        5,
    )
    .await?;
    let streams: Vec<Value> = serde_json::from_str(&output)?;
    command::run(
        "pactl",
        &[
            if playback {
                "set-default-sink"
            } else {
                "set-default-source"
            },
            target,
        ],
        5,
    )
    .await?;
    for stream in streams {
        if !movable_stream(&stream, playback, old_index) {
            continue;
        }
        if let Some(index) = stream["index"].as_u64() {
            let _ = command::run(
                "pactl",
                &[
                    if playback {
                        "move-sink-input"
                    } else {
                        "move-source-output"
                    },
                    &index.to_string(),
                    target,
                ],
                5,
            )
            .await;
        }
    }
    Ok(())
}

fn movable_stream(stream: &Value, playback: bool, from: Option<u64>) -> bool {
    from.is_some()
        && stream[if playback { "sink" } else { "source" }].as_u64() == from
        && !["application.name", "application.process.binary"]
            .iter()
            .any(|key| {
                stream["properties"][key]
                    .as_str()
                    .is_some_and(|name| name.to_lowercase().contains("wivrn"))
            })
}

pub async fn restore_audio_device(playback: bool, saved: &str) -> Result<()> {
    let nodes = audio_nodes(playback).await?;
    let defaults = audio_defaults().await?;
    let current = defaults.get(if playback {
        "default_sink_name"
    } else {
        "default_source_name"
    });
    let desktop = |node: &&Value| {
        !vr_audio(node)
            && (playback
                || !node["name"]
                    .as_str()
                    .unwrap_or_default()
                    .ends_with(".monitor"))
    };
    let target = nodes
        .iter()
        .filter(desktop)
        .find(|node| node["name"].as_str() == current.map(String::as_str))
        .or_else(|| {
            nodes
                .iter()
                .filter(desktop)
                .find(|node| node["name"].as_str() == Some(saved))
        })
        .or_else(|| nodes.iter().find(desktop))
        .and_then(|node| node["name"].as_str())
        .ok_or_else(|| anyhow::anyhow!("audio_restore_failed"))?;
    let from = nodes
        .iter()
        .find(|node| {
            vr_audio(node)
                && (playback
                    || !node["name"]
                        .as_str()
                        .unwrap_or_default()
                        .ends_with(".monitor"))
        })
        .and_then(|node| node["name"].as_str());
    route_audio(playback, target, from).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn routing_preserves_other_outputs_and_wivrn_transport() {
        let mut stream =
            serde_json::json!({"index": 4, "sink": 8, "properties": {"application.name": "Game"}});
        assert!(movable_stream(&stream, true, Some(8)));
        assert!(!movable_stream(&stream, true, Some(9)));
        assert!(!movable_stream(&stream, true, None));
        stream["properties"]["application.name"] = "WiVRn".into();
        assert!(!movable_stream(&stream, true, Some(8)));
    }
}
