use anyhow::{Context, Result, bail};
use std::process::Stdio;
use std::time::Duration;
use tokio::io::AsyncReadExt;
use tokio::process::Command;

pub async fn run(program: &str, args: &[&str], seconds: u64) -> Result<String> {
    let mut child = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .with_context(|| format!("spawn:{program}"))?;
    let stdout = child.stdout.take().context("stdout")?;
    let stderr = child.stderr.take().context("stderr")?;
    let output = async {
        let (out, err, status) = tokio::try_join!(
            read_output(stdout, 32 * 1024 * 1024),
            read_output(stderr, 64 * 1024),
            async { Ok::<_, anyhow::Error>(child.wait().await?) }
        )?;
        if !status.success() {
            let reason = String::from_utf8_lossy(&err);
            if reason.contains("unauthorized") {
                bail!("unauthorized");
            }
            if reason.contains("INSTALL_FAILED_VERSION_DOWNGRADE") {
                bail!("downgrade");
            }
            if reason.contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
                bail!("signature_mismatch");
            }
            bail!("command_failed:{program}:{}", status.code().unwrap_or(-1));
        }
        Ok(String::from_utf8_lossy(&out).into_owned())
    };
    tokio::time::timeout(Duration::from_secs(seconds), output)
        .await
        .context("timeout")?
}

async fn read_output(reader: impl tokio::io::AsyncRead + Unpin, limit: u64) -> Result<Vec<u8>> {
    let mut bytes = Vec::new();
    reader.take(limit + 1).read_to_end(&mut bytes).await?;
    if bytes.len() as u64 > limit {
        bail!("output_too_large");
    }
    Ok(bytes)
}

pub fn shell_word(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

pub async fn adb(endpoint: &str, args: &[&str], seconds: u64) -> Result<String> {
    let mut command = vec!["-s", endpoint];
    command.extend_from_slice(args);
    run("adb", &command, seconds).await
}

pub async fn shell(endpoint: &str, args: &[&str]) -> Result<String> {
    let remote = args
        .iter()
        .map(|v| shell_word(v))
        .collect::<Vec<_>>()
        .join(" ");
    adb(endpoint, &["shell", &remote], 15).await
}

pub fn package_id(value: &str) -> bool {
    value.contains('.')
        && value.len() <= 255
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'_')
}

pub fn local_address(value: &str) -> bool {
    match value.parse::<std::net::IpAddr>() {
        Ok(std::net::IpAddr::V4(ip)) => ip.is_private() || ip.is_link_local(),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn remote_arguments_cannot_become_shell_code() {
        assert_eq!(shell_word("a'b;$(id)"), "'a'\\''b;$(id)'");
        assert!(!package_id("org.example;reboot"));
        assert!(!package_id("-x"));
        assert!(package_id("org.meumeu.wivrn.github"));
    }

    #[test]
    fn reconnect_only_targets_local_literal_addresses() {
        assert!(local_address("192.168.12.2"));
        assert!(!local_address("example.com"));
        assert!(!local_address("8.8.8.8"));
        assert!(!local_address("127.0.0.1"));
        assert!(!local_address("192.168.1.2:5555;reboot"));
    }

    #[tokio::test]
    async fn timeout_terminates_a_stuck_child() {
        let start = std::time::Instant::now();
        assert!(run("sleep", &["20"], 1).await.is_err());
        assert!(start.elapsed() < Duration::from_secs(3));
    }
}
