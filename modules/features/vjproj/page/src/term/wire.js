import { token } from "#lib/api.js"

const KEEPALIVE = 15000
const FIRST_WAIT = 400
const LONGEST_WAIT = 5000

export const nextWait = (waited) => Math.min(waited * 2, LONGEST_WAIT)

export const address = (target, way, size) => {
  const scheme = location.protocol === "https:" ? "wss:" : "ws:"
  const asked = new URLSearchParams({
    token: token(),
    cols: String(size.cols),
    rows: String(size.rows),
  })
  return `${scheme}//${location.host}${target}/${way}?${asked}`
}

export const wire = (target, plan) => {
  let out = null
  let sending = null
  let beat
  let retry
  let waited = FIRST_WAIT
  let size = plan.size()
  let closed = false
  let living = 0

  const state = (named) => plan.onState?.(named)

  const hush = (socket) => {
    if (!socket) return
    socket.onopen = null
    socket.onclose = null
    socket.onerror = null
    socket.onmessage = null
    socket.close()
  }

  const drop = () => {
    clearInterval(beat)
    clearTimeout(retry)
    hush(out)
    hush(sending)
    out = null
    sending = null
  }

  const again = (mine) => () => {
    if (closed || mine !== living) return
    drop()
    state("lost")
    retry = setTimeout(open, waited)
    waited = nextWait(waited)
  }

  const open = () => {
    if (closed) return
    living += 1
    const lost = again(living)
    state("opening")
    size = plan.size()
    out = new WebSocket(address(target, "out", size))
    out.binaryType = "arraybuffer"
    out.onmessage = (event) => plan.onData(new Uint8Array(event.data))
    out.onclose = lost
    out.onerror = lost
    out.onopen = () => {
      sending = new WebSocket(address(target, "in", size))
      sending.binaryType = "arraybuffer"
      sending.onclose = lost
      sending.onerror = lost
      sending.onopen = () => {
        waited = FIRST_WAIT
        state("open")
        beat = setInterval(() => tell(size), KEEPALIVE)
      }
    }
  }

  const tell = (asked) => {
    size = asked
    if (sending?.readyState === WebSocket.OPEN) sending.send(JSON.stringify(asked))
  }

  open()

  return {
    type: (bytes) => {
      if (sending?.readyState === WebSocket.OPEN) sending.send(bytes)
    },
    resize: tell,
    close: () => {
      closed = true
      drop()
    },
  }
}
