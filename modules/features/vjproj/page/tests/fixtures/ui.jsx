import { Show, createSignal } from "solid-js"
import { render } from "solid-js/web"
import { MachineRow, NotifyRow, ProjectGroup } from "#ui/Places.jsx"
import { AgentRow } from "#ui/Agents.jsx"
import { Picker } from "#ui/Sheet.jsx"
import { Spinner } from "#ui/Feedback.jsx"

export const mountProjectGroup = (host, props) => render(() => <ProjectGroup {...props} />, host)

export const mountAgentRow = (host, props) => render(() => <ul><AgentRow {...props} /></ul>, host)

export const mountMachineRow = (host, props) => render(() => <ul><MachineRow {...props} /></ul>, host)

export const mountNotifyRow = (host, props) => render(() => <ul><NotifyRow {...props} /></ul>, host)

export const mountPicker = (host, props) => render(() => <Picker {...props} />, host)

export const signal = createSignal

const Screen = (props) => {
  let box
  return (
    <div class="screen">
      <div class="host" ref={box} />
      <Show when={props.waiting()}>
        <p class="waiting">
          <Spinner />
        </p>
      </Show>
    </div>
  )
}

export const mountScreen = (where, waiting) => {
  render(() => <Screen waiting={waiting} />, where)
  return () => where.querySelector(".host")
}

export { address, nextWait } from "#term/wire.js"
export { ask, forget, token } from "#lib/api.js"
export { themed, SHADES } from "#lib/paint.js"
export { bytesOf, supported } from "#lib/push.js"
