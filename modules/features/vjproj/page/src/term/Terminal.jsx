import { Show, createEffect, createSignal, onCleanup, onMount } from "solid-js"
import { Spinner } from "#ui/Feedback.jsx"
import { Terminal as Xterm } from "@xterm/xterm"
import { FitAddon } from "@xterm/addon-fit"
import { wire } from "#term/wire.js"
import { NEWLINE, chord, wantsNewline } from "#lib/keys.js"
import { held, latched, unlatch } from "#lib/latch.js"
import { EDGE, leans } from "#lib/gesture.js"
import {
  STALE,
  cellAt,
  drifting,
  eased,
  flicked,
  notches,
  paced,
  stride,
  watching,
  wheels,
} from "#lib/wheel.js"
import { paint } from "#lib/paint.js"

const ZOOM = "vjproj.zoom"
const READABLE = 12
const LINE = 1.15
const SETTLE = 200
const PAN_SLOP = 8
const LONGEST = 64

const storedZoom = () => {
  const raw = Number(localStorage.getItem(ZOOM))
  return Number.isFinite(raw) && raw > 0 ? raw : 1
}

const [zoom, setZoom] = createSignal(storedZoom())

const spread = (touches) => {
  const [a, b] = touches
  return Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY)
}

const touching = (node, hands) => {
  const listen = (act) => {
    for (const [name, hand] of Object.entries(hands)) {
      node[act](name, hand, { capture: true, passive: name !== "touchmove" })
    }
  }
  listen("addEventListener")
  return () => listen("removeEventListener")
}

export const Terminal = (props) => {
  const [state, setState] = createSignal("opening")
  let box
  let frame
  let term
  let fit
  let link
  let pinch = null
  let pan = null
  let settle
  let gliding = 0

  const screenOf = () => term?.element?.querySelector(".xterm-screen")

  const cellHeight = () => {
    const seen = screenOf()?.getBoundingClientRect().height ?? 0
    return seen > 0 && term.rows > 0 ? seen / term.rows : READABLE * zoom() * LINE
  }

  const gap = () => stride(cellHeight(), watching(term.modes))

  const roll = (rows, at) => {
    if (!term || rows === 0) return true
    const spot = screenOf()?.getBoundingClientRect()
    if (watching(term.modes) && spot) {
      link?.type(new TextEncoder().encode(wheels(rows, cellAt(spot, term, at))))
      return true
    }
    const was = term.buffer.active.viewportY
    term.scrollLines(rows)
    return term.buffer.active.viewportY !== was
  }

  const rest = () => {
    cancelAnimationFrame(gliding)
    gliding = 0
  }

  const glide = (speed, apart, at) => {
    let carried = 0
    let last = performance.now()
    const tick = (now) => {
      const ms = Math.min(now - last, LONGEST)
      last = now
      carried += speed * ms
      const rows = notches(carried, apart)
      carried -= rows * apart
      speed = eased(speed, ms)
      if (!roll(-rows, at) || !drifting(speed)) return rest()
      gliding = requestAnimationFrame(tick)
    }
    gliding = requestAnimationFrame(tick)
  }

  const measure = () => {
    fit.fit()
    return { cols: term.cols, rows: term.rows }
  }

  const refit = () => {
    if (!term) return
    term.options.fontSize = READABLE * zoom()
    link?.resize(measure())
  }

  const later = () => {
    clearTimeout(settle)
    settle = setTimeout(refit, SETTLE)
  }

  const onTouchStart = (event) => {
    rest()
    pan = null
    pinch = null
    if (event.touches.length === 2) {
      pinch = { from: spread(event.touches) || 1, was: zoom(), now: zoom() }
      return
    }
    if (event.touches.length !== 1) return
    const touch = event.touches[0]
    if (touch.clientX <= EDGE) return
    pan = {
      from: { x: touch.clientX, y: touch.clientY },
      anchor: touch.clientY,
      x: touch.clientX,
      y: touch.clientY,
      at: event.timeStamp,
      speed: 0,
      gap: 0,
      rolling: false,
    }
  }

  const onTouchMove = (event) => {
    if (pinch && event.touches.length === 2) {
      event.stopPropagation()
      event.preventDefault()
      pinch.now = Math.max(0.4, Math.min(3, pinch.was * (spread(event.touches) / pinch.from)))
      term.options.fontSize = READABLE * pinch.now
      return
    }
    if (!pan || event.touches.length !== 1) return

    const touch = event.touches[0]
    const dx = touch.clientX - pan.from.x
    const dy = touch.clientY - pan.from.y
    if (!pan.rolling && leans(dx, dy)) return (pan = null)

    event.stopPropagation()
    event.preventDefault()

    if (!pan.rolling) {
      if (Math.abs(dy) < PAN_SLOP || Math.abs(dy) < Math.abs(dx)) return
      pan.rolling = true
      pan.gap = gap()
    }

    pan.speed = paced(pan.speed, touch.clientY - pan.y, event.timeStamp - pan.at)
    pan.x = touch.clientX
    pan.y = touch.clientY
    pan.at = event.timeStamp

    const rows = notches(pan.y - pan.anchor, pan.gap)
    if (rows === 0) return
    pan.anchor += rows * pan.gap
    roll(-rows, { x: pan.x, y: pan.y })
  }

  const onTouchEnd = (event) => {
    const going = pan
    pan = null
    if (pinch) {
      const now = pinch.now
      pinch = null
      localStorage.setItem(ZOOM, String(now))
      setZoom(now)
      refit()
      return
    }
    if (!going?.rolling || event.timeStamp - going.at > STALE) return
    if (flicked(going.speed)) glide(going.speed, going.gap, { x: going.x, y: going.y })
  }

  const onTouchOff = () => {
    pan = null
    pinch = null
    rest()
  }

  onMount(() => {
    term = new Xterm({
      fontFamily: '"JetBrains Mono", ui-monospace, monospace',
      fontSize: READABLE * zoom(),
      lineHeight: LINE,
      cursorBlink: true,
      scrollback: 5000,
      allowProposedApi: true,
      theme: paint(),
    })
    fit = new FitAddon()
    term.loadAddon(fit)
    term.open(box)

    link = wire(props.target(), {
      size: measure,
      onData: (bytes) => term.write(bytes),
      onState: setState,
    })
    props.onWire?.(link)

    term.attachCustomKeyEventHandler((event) => {
      if (!wantsNewline(event)) return true
      link.type(new TextEncoder().encode(NEWLINE))
      return false
    })

    term.onData((data) => {
      if (!held()) return link.type(new TextEncoder().encode(data))
      const struck = chord(data, latched())
      unlatch()
      link.type(new TextEncoder().encode(struck))
    })
    term.onBinary((data) =>
      link.type(Uint8Array.from(data, (character) => character.charCodeAt(0) & 255)),
    )

    createEffect(() => {
      term.options.fontSize = READABLE * zoom()
      later()
    })

    onCleanup(
      touching(frame, {
        touchstart: onTouchStart,
        touchmove: onTouchMove,
        touchend: onTouchEnd,
        touchcancel: onTouchOff,
      }),
    )

    const watch = new ResizeObserver(later)
    watch.observe(box)
    onCleanup(() => watch.disconnect())
  })

  onCleanup(() => {
    rest()
    clearTimeout(settle)
    props.onWire?.(null)
    link?.close()
    term?.dispose()
  })

  return (
    <div class="screen" classList={{ behind: props.hidden?.() }} ref={frame}>
      <div class="host" ref={box} />
      <Show when={state() !== "open"}>
        <p class="waiting">
          <Spinner />
          <span>{state() === "opening" ? "Connecting" : "Reconnecting"}</span>
        </p>
      </Show>
    </div>
  )
}
