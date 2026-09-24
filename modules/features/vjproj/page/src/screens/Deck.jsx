import { For, Show, createEffect, createSignal, onCleanup, onMount } from "solid-js"
import { IconButton } from "#ui/Button.jsx"
import { Page, Back } from "#ui/Page.jsx"
import { Empty } from "#ui/Feedback.jsx"
import { KindIcon } from "#ui/Agents.jsx"
import { Terminal } from "#term/Terminal.jsx"
import { Keyboard } from "#term/Keyboard.jsx"
import { standingOf } from "#screens/Pane.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { EDGE, drag, nudged } from "#lib/gesture.js"
import { askClose } from "#lib/ask.js"
import { deckAt, path, scope, setDeckAt } from "#lib/store.js"
import { unlatch } from "#lib/latch.js"
import { now } from "#lib/clock.js"
import { alike, kept, nameOf, openAgents, signalOf } from "#lib/model.js"

export const Deck = () => {
  const agents = () => openAgents(scope())
  const at = () => Math.min(deckAt(), Math.max(0, agents().length - 1))
  const agent = () => agents()[at()]
  const here = () => agent()?.pane
  const [open, setOpen] = createSignal([], { equals: alike })
  const [wires, setWires] = createSignal({})
  let tabs

  const panes = () => agents().map((one) => one.pane)
  const shown = () => panes().filter((pane) => open().includes(pane))
  const link = () => wires()[here()] ?? null

  createEffect(() => setOpen((was) => kept(was, here(), panes())))

  createEffect(() => {
    const index = at()
    tabs?.children[index]?.scrollIntoView?.({ block: "nearest", inline: "center", behavior: "smooth" })
  })

  const step = (by) => {
    const next = Math.max(0, Math.min(agents().length - 1, at() + by))
    if (next !== at()) setDeckAt(next)
  }

  onMount(unlatch)

  const swipe = (body) => {
    const stop = drag(body, {
      accepts: (touch, node) => {
        if (touch.clientX <= EDGE || agents().length < 2) return false
        const screen = node.querySelector(".screen:not(.behind)")
        return !screen || screen.scrollWidth <= screen.clientWidth
      },
      onMove: (dx) => {
        body.style.transition = "none"
        body.style.transform = `translateX(${dx * 0.3}px)`
      },
      onEnd: (dx) => {
        body.style.transition = "transform .18s ease-out"
        body.style.transform = ""
        const way = nudged(dx, window.innerWidth)
        if (way !== 0) {
          navigator.vibrate?.(8)
          step(-way)
        }
      },
    })
    onCleanup(stop)
  }

  return (
    <Page
      fixed
      raised
      leading={<Back />}
      title={agent() ? nameOf(agent()) : "Agents"}
      subtitle={agent() ? standingOf(agent(), now()) : ""}
      actions={
        <Show when={agent()}>
          <IconButton icon={GLYPHS.remove} label="Close this agent" onClick={() => askClose(agent().pane)} />
        </Show>
      }
    >
      <Show when={agent()} fallback={<Empty icon={GLYPHS.agents} title="No agents running." />}>
        <div class="tabs" ref={tabs} role="tablist">
          <For each={agents()}>
            {(one, index) => (
              <button
                type="button"
                role="tab"
                class={`tab pressable ${signalOf(one)}`}
                aria-selected={index() === at()}
                onClick={() => setDeckAt(index())}
              >
                <KindIcon kind={one.kind} />
                <span class="tab-label">{nameOf(one)}</span>
                <span class={`dot ${signalOf(one)} ${one.kind}`} />
              </button>
            )}
          </For>
        </div>

        <div class="stack" ref={swipe}>
          <For each={shown()}>
            {(pane) => (
              <Terminal
                target={() => path(`/pane/${pane}`)}
                hidden={() => pane !== here()}
                onWire={(made) => setWires((was) => ({ ...was, [pane]: made }))}
              />
            )}
          </For>
        </div>

        <Keyboard link={link} />
      </Show>
    </Page>
  )
}
