import { createSignal } from "solid-js"

const ROOT = { at: "projects" }

const NESTED = new Set(["pane", "make", "deck"])

const FADES = 6000

const [view, setView] = createSignal(ROOT)
const [note, setNote] = createSignal(null)

let fading

export { view, note }

export const oops = () => (note()?.tone === "error" ? note().text : "")

export const hush = () => {
  clearTimeout(fading)
  setNote(null)
}

const say = (text, tone) => {
  clearTimeout(fading)
  setNote({ text, tone })
  fading = setTimeout(hush, FADES)
}

export const complain = (text) => say(text, "error")

export const inform = (text) => say(text, "info")

export const goto = (at, extra = {}, { replace = false } = {}) => {
  const here = view()
  const entering = Object.hasOwn(extra, "machine")
  const machine = entering ? extra.machine : here.machine
  const deeper = NESTED.has(at) || entering
  const behind = replace ? here.from : here
  setView({ at, ...extra, machine, from: deeper ? behind : undefined })
  if (replace) history.replaceState({ vjproj: true }, "")
  else history.pushState({ vjproj: true }, "")
}

export const upFrom = (here) => {
  if (here.from) return here.from
  if (here.machine && here.at !== "projects") return { at: "projects", machine: here.machine }
  return ROOT
}

export const atRoot = () => view() === ROOT

export const popped = () => setView(upFrom(view()))

export const retreat = () => history.back()
