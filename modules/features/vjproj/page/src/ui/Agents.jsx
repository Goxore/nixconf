import { For, Show } from "solid-js"
import { Icon } from "#ui/Icon.jsx"
import { ListRow } from "#ui/List.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { now } from "#lib/clock.js"
import { detailOf, isOpen, nameOf, signalOf, waiting } from "#lib/model.js"

export const SIGNALS = {
  alert: { label: "Needs you", glyph: GLYPHS.alert },
  done: { label: "Done", glyph: GLYPHS.done },
  working: { label: "Working", glyph: GLYPHS.working },
  idle: { label: "Idle", glyph: GLYPHS.idle },
}

const KIND_GLYPH = { codex: GLYPHS.codex, opencode: GLYPHS.opencode }

export const KindIcon = (props) => <Icon name={KIND_GLYPH[props.kind] ?? GLYPHS.agents} />

export const Signal = (props) => (
  <span class={`signal ${props.of}`}>
    <Icon name={SIGNALS[props.of].glyph} filled={props.of !== "working"} />
    <span>{SIGNALS[props.of].label}</span>
    <Show when={props.since}>
      <span class="since">{props.since}</span>
    </Show>
  </span>
)

export const Dots = (props) => (
  <span class="dots">
    <For each={props.agents}>{(agent) => <span class={`dot ${signalOf(agent)} ${agent.kind}`} />}</For>
  </span>
)

export const AgentRow = (props) => {
  const signal = () => signalOf(props.agent)
  return (
    <ListRow
      tone={signal() === "alert" ? "urgent" : ""}
      quiet={!isOpen(props.agent)}
      leading={<KindIcon kind={props.agent.kind} />}
      headline={nameOf(props.agent)}
      supporting={props.agent.notice || detailOf(props.agent)}
      asking={Boolean(props.agent.notice)}
      trailing={<Signal of={signal()} since={waiting(props.agent, now())} />}
      onClick={() => props.onOpen?.(props.agent)}
    />
  )
}
