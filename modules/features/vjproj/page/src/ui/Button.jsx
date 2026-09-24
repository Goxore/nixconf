import { Show } from "solid-js"
import { Icon } from "#ui/Icon.jsx"

export const Button = (props) => (
  <button
    type={props.type ?? "button"}
    class={`button pressable ${props.variant ?? "filled"}`}
    classList={{ "with-icon": Boolean(props.icon) }}
    disabled={props.disabled}
    onClick={props.onClick}
  >
    <Show when={props.icon}>
      <Icon name={props.icon} />
    </Show>
    <span>{props.children}</span>
  </button>
)

export const IconButton = (props) => (
  <button
    type="button"
    class={`icon-button pressable ${props.variant ?? "standard"}`}
    aria-label={props.label}
    title={props.label}
    disabled={props.disabled}
    onClick={props.onClick}
  >
    <Icon name={props.icon} filled={props.filled} />
    <Show when={props.badge}>
      <span class="badge">{props.badge}</span>
    </Show>
  </button>
)

export const Fab = (props) => (
  <button type="button" class="fab pressable" onClick={props.onClick}>
    <Icon name={props.icon} />
    <span>{props.children}</span>
  </button>
)
