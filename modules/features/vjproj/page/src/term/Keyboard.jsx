import { For, onCleanup } from "solid-js"
import { MODIFIERS, PRESSES, chord } from "#lib/keys.js"
import { latched, pressed, toggle, unlatch } from "#lib/latch.js"
import { slipped } from "#lib/gesture.js"

const HOLD = 400
const REPEAT = 60
const SLIP = 10

const tick = () => navigator.vibrate?.(8)

const tap = (link, code) => link?.type(new TextEncoder().encode(code))

export const Keyboard = (props) => {
  let repeat
  let touch = null

  const fire = (code) => {
    tick()
    const struck = chord(code, latched())
    unlatch()
    tap(props.link(), struck)
    return struck
  }

  const stop = () => {
    clearTimeout(repeat)
    clearInterval(repeat)
    repeat = undefined
  }

  const began = (event, spec) => {
    stop()
    touch = { x: event.clientX, y: event.clientY, spec, fired: false, gone: false }
    if (!spec.repeats) return
    repeat = setTimeout(() => {
      if (!touch || touch.gone) return
      touch.fired = true
      const struck = fire(spec.code)
      repeat = setInterval(() => tap(props.link(), struck), REPEAT)
    }, HOLD)
  }

  const moved = (event) => {
    if (!touch || touch.gone) return
    if (!slipped(event.clientX - touch.x, event.clientY - touch.y, SLIP)) return
    touch.gone = true
    stop()
  }

  const lifted = () => {
    stop()
    const held = touch
    touch = null
    if (!held || held.gone || held.fired) return
    fire(held.spec.code)
  }

  const dropped = () => {
    stop()
    if (touch) touch.gone = true
    touch = null
  }

  onCleanup(stop)

  return (
    <div class="keys" role="toolbar" aria-label="Keys" onMouseDown={(event) => event.preventDefault()}>
      <For each={MODIFIERS}>
        {(mod) => (
          <button
            type="button"
            class="key modifier pressable"
            aria-pressed={pressed(mod.flag)}
            onClick={() => {
              tick()
              toggle(mod.flag)
            }}
          >
            {mod.label}
          </button>
        )}
      </For>
      <For each={PRESSES}>
        {(spec) => (
          <button
            type="button"
            class="key pressable"
            onPointerDown={(event) => began(event, spec)}
            onPointerMove={moved}
            onPointerUp={lifted}
            onPointerCancel={dropped}
            onPointerLeave={dropped}
          >
            {spec.label}
          </button>
        )}
      </For>
    </div>
  )
}
