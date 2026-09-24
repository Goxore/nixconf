import { Show } from "solid-js"
import { Icon } from "#ui/Icon.jsx"
import { note } from "#lib/nav.js"

export const Empty = (props) => (
  <div class="empty">
    <span class="empty-icon">
      <Icon name={props.icon} />
    </span>
    <p class="empty-title">{props.title}</p>
    <Show when={props.children}>
      <p class="empty-text">{props.children}</p>
    </Show>
  </div>
)

export const Spinner = () => <span class="spinner" role="progressbar" aria-busy="true" />

export const Snackbar = () => (
  <Show when={note()}>
    <p class={`snackbar ${note().tone}`} role="status">
      {note().text}
    </p>
  </Show>
)
