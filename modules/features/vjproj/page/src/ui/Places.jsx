import { For, Show } from "solid-js"
import { PlaceIcon, Icon } from "#ui/Icon.jsx"
import { IconButton } from "#ui/Button.jsx"
import { ListGroup, ListRow } from "#ui/List.jsx"
import { AgentRow, Dots } from "#ui/Agents.jsx"
import { Switch } from "#ui/Controls.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { basename, byUrgency, signalOf, tilde } from "#lib/model.js"

export const Avatar = (props) => (
  <span class="avatar" classList={{ here: props.here }}>
    <PlaceIcon name={props.icon} filled={props.here} />
  </span>
)

export const ProjectGroup = (props) => (
  <ListGroup>
    <ListRow
      tone={props.agents[0] && signalOf(props.agents[0]) === "alert" ? "urgent" : ""}
      leading={<Avatar icon={props.place?.icon} here={props.active} />}
      headline={props.label}
      supporting={tilde(props.home, props.place?.dir ?? "")}
      trailing={
        <>
          <Show when={props.active}>
            <span class="here-badge">Here</span>
          </Show>
          <Dots agents={props.agents} />
        </>
      }
      onClick={props.onOpen}
      action={<IconButton icon={GLYPHS.add} label={`Start an agent in ${props.label}`} onClick={props.onStart} />}
    />
    <For each={props.agents}>{(agent) => <AgentRow agent={agent} onOpen={props.onOpenAgent} />}</For>
  </ListGroup>
)

export const ShelfRow = (props) => (
  <ListRow
    leading={<Avatar icon={props.profile.icon} />}
    headline={props.profile.name || basename(props.profile.dir ?? "")}
    supporting={tilde(props.home, props.profile.dir ?? "")}
    trailing={<Icon name={GLYPHS.forward} />}
    onClick={props.onOpen}
  />
)

export const MachineRow = (props) => {
  const agents = () => (props.peer.state?.agents ?? []).slice().sort(byUrgency)
  return (
    <ListRow
      tone={agents()[0] && signalOf(agents()[0]) === "alert" ? "urgent" : ""}
      leading={<Icon name={GLYPHS.machine} />}
      headline={props.peer.host}
      supporting={agents().length === 1 ? "1 agent" : `${agents().length} agents`}
      trailing={
        <>
          <Dots agents={agents()} />
          <Icon name={GLYPHS.forward} />
        </>
      }
      onClick={props.onOpen}
    />
  )
}

export const NOTIFY = {
  off: "When an agent needs you",
  on: "When an agent needs you",
  blocked: "Blocked by this browser",
}

export const NotifyRow = (props) => (
  <Show when={NOTIFY[props.standing]}>
    <ListRow
      role="switch"
      checked={props.standing === "on" ? "true" : "false"}
      quiet={props.standing === "blocked"}
      leading={<Icon name={props.standing === "blocked" ? GLYPHS.notifyOff : GLYPHS.notify} />}
      headline="Notifications"
      supporting={NOTIFY[props.standing]}
      trailing={<Switch on={props.standing === "on"} />}
      onClick={props.onToggle}
    />
  </Show>
)
