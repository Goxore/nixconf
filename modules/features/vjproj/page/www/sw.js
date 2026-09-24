const KEEP = "vjproj.keep"
const TOKEN = "/vjproj/token"

const kept = async () => {
  const store = await caches.open(KEEP)
  const held = await store.match(TOKEN)
  return held ? (await held.text()).trim() : ""
}

const stateNow = async () => {
  const token = await kept()
  if (!token) return null
  const answer = await fetch("/state", {
    cache: "no-store",
    headers: { Authorization: `Bearer ${token}` },
  })
  return answer.ok ? answer.json() : null
}

const nameOf = (agent) => {
  const cwd = (agent.cwd || "").replace(/\/+$/, "")
  return agent.title || cwd.split("/").pop() || agent.kind || "Agent"
}

const wanting = (state) =>
  (state?.agents ?? [])
    .filter((agent) => agent.attention)
    .sort((a, b) => (b.updated ?? 0) - (a.updated ?? 0))

const tell = (agent) =>
  self.registration.showNotification(agent ? nameOf(agent) : "vjproj", {
    body: agent?.notice || "Waiting for your input",
    icon: "/icon-192.png",
    badge: "/icon-mask.png",
    tag: agent ? `vjproj-${agent.pid}` : "vjproj",
    data: { pane: agent?.pane ?? null },
  })

const show = async () => {
  const asking = wanting(await stateNow().catch(() => null))
  await Promise.all(asking.length > 0 ? asking.map(tell) : [tell(null)])
}

self.addEventListener("install", () => self.skipWaiting())

self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()))

self.addEventListener("fetch", () => {})

self.addEventListener("push", (event) => event.waitUntil(show()))

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((open) => {
      const here = open.find((one) => one.url.startsWith(self.registration.scope))
      if (here) return here.focus()
      return self.clients.openWindow("/")
    }),
  )
})
