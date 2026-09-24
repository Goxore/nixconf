import { createSignal } from "solid-js"
import { ask, send, token } from "#lib/api.js"

const KEEP = "vjproj.keep"
const TOKEN = "/vjproj/token"
const SCOPE = "/"
const WORKER = "/sw.js"

const [standing, setStanding] = createSignal("unknown")

export { standing }

export const bytesOf = (raw) => {
  const plain = raw.replace(/-/g, "+").replace(/_/g, "/")
  const filled = plain + "=".repeat((4 - (plain.length % 4)) % 4)
  return Uint8Array.from(atob(filled), (one) => one.charCodeAt(0))
}

export const supported = () =>
  typeof navigator === "object" &&
  "serviceWorker" in navigator &&
  typeof window === "object" &&
  "PushManager" in window &&
  "Notification" in window

const remember = async () => {
  const store = await caches.open(KEEP)
  await store.put(TOKEN, new Response(token()))
}

const registered = () => navigator.serviceWorker.getRegistration(SCOPE)

const living = async () => (await registered())?.pushManager.getSubscription()

export const settle = async () => {
  if (!supported()) return setStanding("unsupported")
  await navigator.serviceWorker.register(WORKER, { scope: SCOPE }).catch(() => {})
  if (Notification.permission === "denied") return setStanding("blocked")
  const live = await living().catch(() => null)
  if (live) {
    await remember().catch(() => {})
    await send("/push/subscribe", { endpoint: live.endpoint }).catch(() => {})
  }
  setStanding(live ? "on" : "off")
}

export const enable = async () => {
  if (!supported()) return
  const allowed = await Notification.requestPermission()
  if (allowed !== "granted") return setStanding(allowed === "denied" ? "blocked" : "off")

  const registration = await navigator.serviceWorker.register(WORKER, { scope: SCOPE })
  await navigator.serviceWorker.ready
  const { key } = await ask("/push/key")
  const live =
    (await registration.pushManager.getSubscription()) ??
    (await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: bytesOf(key),
    }))

  await remember()
  await send("/push/subscribe", { endpoint: live.endpoint })
  setStanding("on")
}

export const disable = async () => {
  const live = await living().catch(() => null)
  if (live) {
    await send("/push/forget", { endpoint: live.endpoint }).catch(() => {})
    await live.unsubscribe().catch(() => {})
  }
  setStanding("off")
}
