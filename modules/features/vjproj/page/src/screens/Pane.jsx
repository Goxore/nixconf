import { createSignal, onCleanup, onMount } from "solid-js"
import { IconButton } from "#ui/Button.jsx"
import { Page, Back } from "#ui/Page.jsx"
import { SIGNALS } from "#ui/Agents.jsx"
import { Terminal } from "#term/Terminal.jsx"
import { Keyboard } from "#term/Keyboard.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { view } from "#lib/nav.js"
import { askClose } from "#lib/ask.js"
import { path, scope } from "#lib/store.js"
import { unlatch } from "#lib/latch.js"
import { now } from "#lib/clock.js"
import { nameOf, signalOf, waiting } from "#lib/model.js"
import { send } from "#lib/api.js"

export const standingOf = (agent, at) => {
  const since = waiting(agent, at)
  const label = SIGNALS[signalOf(agent)].label
  return since ? `${label} · ${since}` : label
}

export const Pane = () => {
  const opened = view()
  const [link, setLink] = createSignal(null)
  const agent = () => (scope()?.agents ?? []).find((one) => one.pid === opened.pid)
  const title = () => (agent() ? nameOf(agent()) : (opened.label ?? ""))

  onMount(unlatch)

  onCleanup(() => {
    if (opened.shell === undefined) return
    send(path(`/shell/${opened.shell}/release`)).catch(() => {})
  })

  return (
    <Page
      fixed
      raised
      leading={<Back />}
      title={title()}
      subtitle={agent() ? standingOf(agent(), now()) : "Shell"}
      actions={
        <IconButton icon={GLYPHS.remove} label={agent() ? "Close this agent" : "Close this shell"} onClick={() => askClose(opened.pane)} />
      }
    >
      <Terminal target={() => path(`/pane/${opened.pane}`)} onWire={setLink} />
      <Keyboard link={link} />
    </Page>
  )
}
