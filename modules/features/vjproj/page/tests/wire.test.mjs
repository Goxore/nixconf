import test from "node:test"
import assert from "node:assert/strict"

import "./fixtures/stubs.mjs"

const { address, nextWait, themed, SHADES } = await import("./.built/ui.mjs")

test("a terminal socket carries the token and the size it wants", () => {
  const url = new URL(address("/pane/12", "out", { cols: 47, rows: 33 }))
  assert.equal(url.protocol, "ws:")
  assert.equal(url.host, "main:8422")
  assert.equal(url.pathname, "/pane/12/out")
  assert.equal(url.searchParams.get("token"), "sekret")
  assert.equal(url.searchParams.get("cols"), "47")
  assert.equal(url.searchParams.get("rows"), "33")
})

test("a pane on another machine keeps that machine in the path", () => {
  const url = new URL(address("/at/mini/pane/7", "in", { cols: 80, rows: 24 }))
  assert.equal(url.pathname, "/at/mini/pane/7/in")
})

test("a page served over https opens a secure socket", () => {
  globalThis.location.protocol = "https:"
  assert.equal(new URL(address("/pane/1", "out", { cols: 80, rows: 24 })).protocol, "wss:")
  globalThis.location.protocol = "http:"
})

test("a socket that keeps failing backs off but never gives up slowly forever", () => {
  let waited = 400
  const seen = []
  for (let i = 0; i < 6; i += 1) {
    seen.push(waited)
    waited = nextWait(waited)
  }
  assert.deepEqual(seen, [400, 800, 1600, 3200, 5000, 5000])
})




test("the terminal is painted from the page theme, all sixteen colours", () => {
  const theme = themed((name) => `var(${name})`)
  assert.equal(theme.background, "var(surface)")
  assert.equal(theme.foreground, "var(ink-surface)")
  assert.equal(theme.black, "var(ansi-0)")
  assert.equal(theme.brightWhite, "var(ansi-15)")
  assert.equal(SHADES.length, 16)
})

test("a token the machine no longer accepts is dropped rather than retried forever", async () => {
  const { ask, forget, token } = await import("./.built/ui.mjs")
  assert.equal(token(), "sekret", "the stored token is in play to begin with")

  globalThis.fetch = async () => ({ ok: false, status: 401, json: async () => ({}) })
  await assert.rejects(() => ask("/state"), /401/)

  assert.equal(token(), "", "a refused token is forgotten so the page can ask for a new one")
  forget()
})
