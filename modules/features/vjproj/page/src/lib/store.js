import { createSignal } from "solid-js"
import { createStore, reconcile } from "solid-js/store"
import { ask, on } from "#lib/api.js"
import { view } from "#lib/nav.js"

const [feed, setFeed] = createStore({ state: null })
const [reachable, setReachable] = createSignal(true)
const [deckAt, setDeckAt] = createSignal(0)

export { reachable, deckAt, setDeckAt }

export const peers = () => feed.state?.peers ?? []

export const peerOf = (host) => peers().find((peer) => peer.host === host) ?? null

export const scope = () => {
  const machine = view().machine
  return machine ? (peerOf(machine)?.state ?? null) : feed.state
}

export const path = (rest) => on(view().machine, rest)

export const pullState = async () => {
  try {
    setFeed("state", reconcile(await ask("/state"), { merge: true }))
    setReachable(true)
  } catch {
    setReachable(false)
  }
}

