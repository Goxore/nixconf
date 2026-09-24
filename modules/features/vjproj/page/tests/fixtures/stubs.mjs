import { parseHTML } from "linkedom"

const { window, document } = parseHTML(
  "<!doctype html><html><head></head><body><div id='app'></div></body></html>",
)

const store = new Map([["vjproj.token", "sekret"]])

globalThis.window = window
globalThis.document = document
globalThis.Node = window.Node
globalThis.Element = window.Element
globalThis.HTMLElement = window.HTMLElement
globalThis.SVGElement = window.SVGElement
globalThis.getComputedStyle = () => ({ getPropertyValue: () => "" })
globalThis.location = { protocol: "http:", host: "main:8422", hash: "", search: "", pathname: "/" }
globalThis.history = { pushState: () => {}, replaceState: () => {}, back: () => {} }
globalThis.localStorage = {
  getItem: (key) => store.get(key) ?? null,
  setItem: (key, value) => store.set(key, String(value)),
  removeItem: (key) => store.delete(key),
}
globalThis.ResizeObserver = class {
  observe() {}
  disconnect() {}
}

export { window, document }

export const host = () => {
  const node = document.createElement("div")
  document.body.append(node)
  return node
}
