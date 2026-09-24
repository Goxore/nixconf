import { icons } from "#lib/icons.js"
import { GLYPHS } from "#lib/glyphs.js"

export const glyphOf = (name) => {
  const point = icons()[name]
  return point ? String.fromCodePoint(point) : ""
}

export const Icon = (props) => (
  <span class="icon" classList={{ filled: props.filled }} aria-hidden="true">
    {glyphOf(props.name)}
  </span>
)

export const PlaceIcon = (props) => (
  <Icon name={icons()[props.name] ? props.name : GLYPHS.project} filled={props.filled} />
)
