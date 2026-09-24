import { Show } from "solid-js"

export const Section = (props) => (
  <section class="section">
    <Show when={props.title}>
      <h2 class="section-title">{props.title}</h2>
    </Show>
    {props.children}
  </section>
)

export const ListGroup = (props) => <ul class="list">{props.children}</ul>

export const ListRow = (props) => (
  <li class={`item ${props.tone ?? ""}`} classList={{ quiet: props.quiet }}>
    <button
      type="button"
      class="row pressable"
      role={props.role}
      aria-checked={props.checked}
      aria-disabled={props.quiet ? "true" : undefined}
      onClick={() => props.quiet || props.onClick?.()}
    >
      <span class="leading">{props.leading}</span>
      <span class="text">
        <span class="headline">{props.headline}</span>
        <Show when={props.supporting}>
          <span class="supporting" classList={{ asking: props.asking }}>
            {props.supporting}
          </span>
        </Show>
      </span>
      <span class="trailing">{props.trailing}</span>
    </button>
    {props.action}
  </li>
)
