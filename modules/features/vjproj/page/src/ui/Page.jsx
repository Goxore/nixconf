import { Show, createSignal } from "solid-js"
import { IconButton } from "#ui/Button.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { retreat } from "#lib/nav.js"

export const Back = () => <IconButton icon={GLYPHS.back} label="Back" onClick={retreat} />

export const Page = (props) => {
  const [raised, setRaised] = createSignal(false)
  return (
    <div class="page">
      <header class="top-bar" classList={{ raised: raised() || props.raised }}>
        {props.leading}
        <div class="titles">
          <h1 class="title">{props.title}</h1>
          <Show when={props.subtitle}>
            <p class="subtitle">{props.subtitle}</p>
          </Show>
        </div>
        <div class="actions">{props.actions}</div>
      </header>
      <Show when={props.fixed} fallback={
        <div class="scroll" classList={{ roomy: Boolean(props.fab) }} onScroll={(event) => setRaised(event.currentTarget.scrollTop > 0)}>
          {props.children}
        </div>
      }>
        {props.children}
      </Show>
      {props.fab}
    </div>
  )
}
