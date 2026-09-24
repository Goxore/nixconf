import { createSignal } from "solid-js"

const [closing, askClose] = createSignal(null)
const [starting, askStart] = createSignal(null)

export { closing, askClose, starting, askStart }
