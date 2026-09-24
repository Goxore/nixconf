import { Icon } from "#ui/Icon.jsx"
import { GLYPHS } from "#lib/glyphs.js"

export const Switch = (props) => (
  <span class="switch" classList={{ on: props.on, off: !props.on }} aria-hidden="true">
    <span class="handle">
      <Icon name={GLYPHS.check} />
    </span>
  </span>
)

export const Field = (props) => (
  <label class="field">
    <input
      ref={props.ref}
      value={props.value ?? ""}
      placeholder=" "
      autocomplete="off"
      autocapitalize="off"
      autocorrect="off"
      spellcheck={false}
      enterkeyhint={props.enter}
      onInput={(event) => props.onInput?.(event.currentTarget.value)}
    />
    <span class="field-label">{props.label}</span>
    <span class="field-support">{props.support}</span>
  </label>
)
