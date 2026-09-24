import { createSignal } from "solid-js"

const [now, setNow] = createSignal(Date.now())

export { now }

export const tick = () => setNow(Date.now())
