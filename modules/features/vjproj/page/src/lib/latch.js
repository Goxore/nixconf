import { createSignal } from "solid-js"

const [ctrl, setCtrl] = createSignal(false)
const [alt, setAlt] = createSignal(false)
const [shift, setShift] = createSignal(false)

const READS = { ctrl, alt, shift }
const WRITES = { ctrl: setCtrl, alt: setAlt, shift: setShift }

export { ctrl, alt, shift }

export const pressed = (flag) => READS[flag]?.() ?? false

export const held = () => ctrl() || alt() || shift()

export const latched = () => ({ ctrl: ctrl(), alt: alt(), shift: shift() })

export const toggle = (flag) => WRITES[flag]?.((on) => !on)

export const unlatch = () => {
  setCtrl(false)
  setAlt(false)
  setShift(false)
}
