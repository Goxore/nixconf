import { For, Show, onCleanup, onMount } from "solid-js"
import { Icon, PlaceIcon } from "#ui/Icon.jsx"
import { Button } from "#ui/Button.jsx"
import { ListGroup, ListRow } from "#ui/List.jsx"
import { KindIcon } from "#ui/Agents.jsx"
import { KINDS } from "#lib/model.js"

const Dismissable = (props) => {
  const escape = (event) => event.key === "Escape" && props.onDismiss()
  onMount(() => window.addEventListener("keydown", escape))
  onCleanup(() => window.removeEventListener("keydown", escape))
  return (
    <div class={`scrim ${props.kind}`} onClick={props.onDismiss}>
      <div class={props.kind} role="dialog" aria-modal="true" aria-label={props.label} onClick={(event) => event.stopPropagation()}>
        {props.children}
      </div>
    </div>
  )
}

export const Dialog = (props) => (
  <Show when={props.when}>
    <Dismissable kind="dialog" label={props.title} onDismiss={props.onDismiss}>
      <span class="dialog-icon">
        <Icon name={props.icon} />
      </span>
      <h2 class="dialog-title">{props.title}</h2>
      <Show when={props.children}>
        <p class="dialog-text">{props.children}</p>
      </Show>
      <div class="dialog-actions">
        <Button variant="text" onClick={props.onDismiss}>
          Cancel
        </Button>
        <Button variant="text danger" onClick={props.onConfirm}>
          {props.confirm}
        </Button>
      </div>
    </Dismissable>
  </Show>
)

export const Picker = (props) => (
  <Show when={props.when}>
    <Dismissable kind="sheet" label={props.title} onDismiss={props.onDismiss}>
      <span class="sheet-handle" />
      <div class="sheet-head">
        <span class="sheet-icon">
          <PlaceIcon name={props.icon} />
        </span>
        <div>
          <h2 class="sheet-title">{props.title}</h2>
          <p class="sheet-text">{props.where}</p>
        </div>
      </div>
      <ListGroup>
        <For each={KINDS}>
          {(kind) => (
            <ListRow
              leading={<KindIcon kind={kind} />}
              headline={kind}
              onClick={() => props.onPick(kind)}
            />
          )}
        </For>
      </ListGroup>
    </Dismissable>
  </Show>
)
