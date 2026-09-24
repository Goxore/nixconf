use crate::{controller::Controller, model::Request};
use anyhow::{Context, Result, bail};
use fs2::FileExt;
use serde_json::Value;
use std::{
    io::Write,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    sync::Arc,
    time::Duration,
};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{UnixListener, UnixStream},
};

pub fn socket_path() -> Result<PathBuf> {
    let runtime = std::env::var_os("XDG_RUNTIME_DIR").context("runtime_unavailable")?;
    Ok(PathBuf::from(runtime).join("vjvr/control.sock"))
}

pub async fn serve(controller: Arc<Controller>, socket: &Path) -> Result<()> {
    let dir = socket.parent().context("invalid_socket")?;
    std::fs::create_dir_all(dir)?;
    std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700))?;
    let lock = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(dir.join("service.lock"))?;
    lock.try_lock_exclusive().context("already_running")?;
    if socket.exists() {
        std::fs::remove_file(socket)?;
    }
    let listener = UnixListener::bind(socket)?;
    std::fs::set_permissions(socket, std::fs::Permissions::from_mode(0o600))?;
    controller.start_monitor();
    let clients = Arc::new(tokio::sync::Semaphore::new(32));
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    loop {
        tokio::select! {
            result = listener.accept() => {
                let Ok((stream, _)) = result else {
                    tokio::time::sleep(Duration::from_millis(100)).await;
                    continue;
                };
                let Ok(permit) = clients.clone().try_acquire_owned() else { continue; };
                let controller = controller.clone();
                tokio::spawn(async move { let _permit = permit; let _ = handle(controller, stream).await; });
            }
            _ = tokio::signal::ctrl_c() => break,
            _ = terminate.recv() => break,
        }
    }
    std::fs::remove_file(socket)?;
    controller.shutdown().await;
    Ok(())
}

async fn handle(controller: Arc<Controller>, stream: UnixStream) -> Result<()> {
    let (read, mut write) = stream.into_split();
    let mut reader = BufReader::new(read);
    let mut bytes = Vec::new();
    let count =
        tokio::time::timeout(Duration::from_secs(5), read_line(&mut reader, &mut bytes)).await??;
    if count == 0 {
        return Ok(());
    }
    let request: Request = serde_json::from_slice(&bytes)?;
    if matches!(request, Request::Watch) {
        let mut state = controller.state.subscribe();
        loop {
            let mut output = serde_json::to_vec(&*state.borrow_and_update())?;
            output.push(b'\n');
            tokio::time::timeout(Duration::from_secs(5), write.write_all(&output)).await??;
            if state.changed().await.is_err() {
                break;
            }
        }
    } else {
        let value = match controller.submit(request).await {
            Ok(value) => serde_json::json!({"ok": true, "data": value}),
            Err(error) => serde_json::json!({"ok": false, "error": error.to_string()}),
        };
        let mut output = serde_json::to_vec(&value)?;
        output.push(b'\n');
        tokio::time::timeout(Duration::from_secs(5), write.write_all(&output)).await??;
    }
    Ok(())
}

async fn read_line<R: tokio::io::AsyncBufRead + Unpin>(
    reader: &mut R,
    bytes: &mut Vec<u8>,
) -> Result<usize> {
    loop {
        let available = reader.fill_buf().await?;
        if available.is_empty() {
            return Ok(bytes.len());
        }
        let count = available
            .iter()
            .position(|b| *b == b'\n')
            .map(|i| i + 1)
            .unwrap_or(available.len());
        if bytes.len() + count > 64 * 1024 {
            bail!("request_too_large");
        }
        bytes.extend_from_slice(&available[..count]);
        reader.consume(count);
        if bytes.last() == Some(&b'\n') {
            return Ok(bytes.len());
        }
    }
}

pub async fn client(socket: &Path, request: Request) -> Result<()> {
    let mut stream = UnixStream::connect(socket)
        .await
        .context("service_unavailable")?;
    let mut data = serde_json::to_vec(&request)?;
    data.push(b'\n');
    stream.write_all(&data).await?;
    let mut lines = BufReader::new(stream).lines();
    while let Some(line) = lines.next_line().await? {
        if !matches!(request, Request::Watch) {
            let value: Value = serde_json::from_str(&line)?;
            println!("{line}");
            if value["ok"] == false {
                bail!("request_failed");
            }
            return Ok(());
        }
        let stdout = std::io::stdout();
        let mut output = stdout.lock();
        writeln!(output, "{line}")?;
        output.flush()?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn client_cannot_allocate_unbounded_request_memory() {
        let bytes = vec![b'x'; 70 * 1024];
        let mut reader = BufReader::new(bytes.as_slice());
        let mut output = Vec::new();
        assert!(read_line(&mut reader, &mut output).await.is_err());
        assert!(output.len() <= 64 * 1024);
    }
}
