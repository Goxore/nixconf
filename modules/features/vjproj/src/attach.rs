use crate::held;
use anyhow::{Context, Result, bail};
use portable_pty::{Child, CommandBuilder, MasterPty, PtySize, native_pty_system};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::{Ipv4Addr, TcpStream};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use tungstenite::handshake::client::generate_key;
use tungstenite::protocol::Role;
use tungstenite::{Message, WebSocket};

const CHUNK: usize = 8192;

const PATIENCE: Duration = Duration::from_secs(2);

pub const FORGOTTEN: Duration = Duration::from_secs(45);

pub const MOST: usize = 8;

pub const SETTLING: Duration = Duration::from_millis(250);

const BEAT: Duration = Duration::from_millis(20);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Size {
    pub cols: u16,
    pub rows: u16,
}

impl Size {
    pub fn fitted(cols: u16, rows: u16) -> Self {
        let (cols, rows) = crate::tmux::fits(cols, rows);
        Self { cols, rows }
    }

    fn asked(&self) -> PtySize {
        PtySize {
            rows: self.rows,
            cols: self.cols,
            pixel_width: 0,
            pixel_height: 0,
        }
    }
}

pub fn crowded(live: usize, already: bool) -> bool {
    !already && live >= MOST
}

pub fn too_soon(last: Option<Instant>, now: Instant) -> bool {
    last.is_some_and(|last| now.duration_since(last) < SETTLING)
}

#[derive(Clone)]
pub struct Live {
    epoch: u64,
    tty: Option<String>,
    seen: Arc<Mutex<Instant>>,
    writer: Arc<Mutex<Box<dyn Write + Send>>>,
    master: Arc<Mutex<Box<dyn MasterPty + Send>>>,
    child: Arc<Mutex<Box<dyn Child + Send + Sync>>>,
}

impl Live {
    pub fn epoch(&self) -> u64 {
        self.epoch
    }

    pub fn heard(&self, now: Instant) {
        *held(&self.seen) = now;
    }

    fn quiet_since(&self, now: Instant) -> Duration {
        now.duration_since(*held(&self.seen))
    }

    pub fn wrote(&self, bytes: &[u8]) -> Result<()> {
        let mut writer = held(&self.writer);
        writer
            .write_all(bytes)
            .context("cannot reach the terminal")?;
        writer.flush().context("cannot reach the terminal")
    }

    pub fn resized(&self, size: Size) -> Result<()> {
        held(&self.master)
            .resize(size.asked())
            .map_err(|e| anyhow::anyhow!("{e}"))
            .context("cannot resize the terminal")
    }

    fn ended(&self) {
        if let Some(tty) = &self.tty {
            let _ = crate::tmux::detach(tty);
        }
        let mut child = held(&self.child);
        let _ = child.kill();
        let _ = child.wait();
    }
}

#[derive(Default)]
pub struct Attached {
    live: Mutex<HashMap<String, Live>>,
    spawned: Mutex<HashMap<String, Instant>>,
    epochs: Mutex<u64>,
}

impl Attached {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn spare(&self, pane: &str, now: Instant) -> Result<()> {
        if too_soon(held(&self.spawned).get(pane).copied(), now) {
            bail!("that terminal was opened a moment ago");
        }
        let live = held(&self.live);
        if crowded(live.len(), live.contains_key(pane)) {
            bail!("too many terminals are open at once");
        }
        Ok(())
    }

    pub fn opened(&self, pane: &str, size: Size) -> Result<(u64, Box<dyn Read + Send>)> {
        let now = Instant::now();
        self.spare(pane, now)?;
        held(&self.spawned).insert(pane.to_owned(), now);

        let pair = native_pty_system()
            .openpty(size.asked())
            .map_err(|e| anyhow::anyhow!("{e}"))
            .context("cannot open a terminal")?;

        let mut command = CommandBuilder::new("tmux");
        command.args(["attach-session", "-t", pane]);
        command.env("TERM", "xterm-256color");
        command.env_remove("TMUX");

        let child = pair
            .slave
            .spawn_command(command)
            .map_err(|e| anyhow::anyhow!("{e}"))
            .context("cannot attach to tmux")?;
        let reader = pair
            .master
            .try_clone_reader()
            .map_err(|e| anyhow::anyhow!("{e}"))
            .context("cannot read the terminal")?;
        let writer = pair
            .master
            .take_writer()
            .map_err(|e| anyhow::anyhow!("{e}"))
            .context("cannot write to the terminal")?;

        let epoch = {
            let mut counter = held(&self.epochs);
            *counter += 1;
            *counter
        };

        let fresh = Live {
            epoch,
            tty: pair
                .master
                .tty_name()
                .map(|name| name.to_string_lossy().into_owned()),
            seen: Arc::new(Mutex::new(Instant::now())),
            writer: Arc::new(Mutex::new(writer)),
            master: Arc::new(Mutex::new(pair.master)),
            child: Arc::new(Mutex::new(child)),
        };
        let displaced = held(&self.live).insert(pane.to_owned(), fresh);
        if let Some(displaced) = displaced {
            displaced.ended();
        }
        Ok((epoch, reader))
    }

    pub fn closed(&self, pane: &str, epoch: u64) {
        let mut live = held(&self.live);
        if live.get(pane).map(|one| one.epoch) != Some(epoch) {
            return;
        }
        let Some(going) = live.remove(pane) else {
            return;
        };
        drop(live);
        going.ended();
    }

    pub fn find(&self, pane: &str) -> Option<Live> {
        held(&self.live).get(pane).cloned()
    }

    fn awaited(&self, pane: &str, patience: Duration) -> Option<Live> {
        let until = Instant::now() + patience;
        loop {
            if let Some(one) = self.find(pane) {
                return Some(one);
            }
            if Instant::now() >= until {
                return None;
            }
            thread::sleep(BEAT);
        }
    }

    pub fn gone_quiet(&self, now: Instant, after: Duration) -> Vec<(String, u64)> {
        held(&self.live)
            .iter()
            .filter(|(_, one)| one.quiet_since(now) >= after)
            .map(|(pane, one)| (pane.clone(), one.epoch))
            .collect()
    }
}

pub fn answers_a_query(bytes: &[u8]) -> bool {
    match bytes {
        [0x1b, b'P', ..] => true,
        [0x1b, b'[', b'?', rest @ ..] => rest.last() == Some(&b'c'),
        [0x1b, b'[', rest @ ..] => {
            rest.last() == Some(&b'R')
                && rest[..rest.len() - 1]
                    .iter()
                    .all(|byte| byte.is_ascii_digit() || *byte == b';')
        }
        _ => false,
    }
}

pub fn from_hand(bytes: &[u8]) -> bool {
    !bytes.is_empty() && !answers_a_query(bytes)
}

pub fn wrapped<S: Read + Write>(stream: S) -> WebSocket<S> {
    WebSocket::from_raw_socket(stream, Role::Server, None)
}

pub fn dialed(address: Ipv4Addr, port: u16, path: &str) -> Result<WebSocket<TcpStream>> {
    let stream = TcpStream::connect((address, port))
        .with_context(|| format!("cannot reach {address}:{port}"))?;
    let asking = tungstenite::http::Request::builder()
        .method("GET")
        .uri(format!("ws://{address}:{port}{path}"))
        .header("Host", format!("{address}:{port}"))
        .header("Connection", "Upgrade")
        .header("Upgrade", "websocket")
        .header("Sec-WebSocket-Version", "13")
        .header("Sec-WebSocket-Key", generate_key())
        .header(crate::http::FORWARDED, "1")
        .body(())
        .context("cannot ask for a terminal")?;
    let (socket, _) = tungstenite::client::client(asking, stream)
        .map_err(|e| anyhow::anyhow!("{e}"))
        .context("the other machine refused the terminal")?;
    Ok(socket)
}

pub fn ferry<A: Read + Write, B: Read + Write>(mut from: WebSocket<A>, mut to: WebSocket<B>) {
    loop {
        let carried = match from.read() {
            Ok(message @ (Message::Binary(_) | Message::Text(_))) => message,
            Ok(Message::Close(_)) | Err(_) => break,
            Ok(_) => continue,
        };
        if to.send(carried).is_err() {
            break;
        }
    }
    let _ = from.close(None);
    let _ = to.close(None);
}

pub fn downstream<S: Read + Write>(
    attached: &Attached,
    pane: &str,
    size: Size,
    stream: S,
) -> Result<()> {
    let (epoch, mut reader) = attached.opened(pane, size)?;
    let mut socket = wrapped(stream);
    let mut buffer = vec![0u8; CHUNK];

    while let Ok(read) = reader.read(&mut buffer) {
        if read == 0 {
            break;
        }
        if socket
            .send(Message::Binary(buffer[..read].to_vec().into()))
            .is_err()
        {
            break;
        }
    }

    let _ = socket.close(None);
    attached.closed(pane, epoch);
    Ok(())
}

#[derive(serde::Deserialize)]
struct Asked {
    cols: u16,
    rows: u16,
}

pub fn upstream<S: Read + Write>(
    attached: &Attached,
    pane: &str,
    stream: S,
    typed: impl Fn(),
) -> Result<()> {
    let Some(live) = attached.awaited(pane, PATIENCE) else {
        bail!("no terminal is open on {pane}");
    };
    let mut socket = wrapped(stream);

    loop {
        let message = socket.read();
        live.heard(Instant::now());
        match message {
            Ok(Message::Binary(bytes)) => {
                if from_hand(&bytes) {
                    typed();
                }
                if live.wrote(&bytes).is_err() {
                    break;
                }
            }
            Ok(Message::Text(raw)) => {
                if let Ok(asked) = serde_json::from_str::<Asked>(&raw) {
                    let _ = live.resized(Size::fitted(asked.cols, asked.rows));
                }
            }
            Ok(Message::Close(_)) | Err(_) => break,
            Ok(_) => {}
        }
    }

    let _ = socket.close(None);
    attached.closed(pane, live.epoch());
    Ok(())
}
