export const RANK = ["alert", "done", "working", "idle"]

export const KINDS = ["claude-per", "claude-fish", "codex", "opencode"]

export const signalOf = (agent) =>
  agent.attention
    ? agent.activity === "blocked" ? "alert" : "done"
    : agent.activity === "idle" ? "idle" : "working"

export const byUrgency = (a, b) =>
  RANK.indexOf(signalOf(a)) - RANK.indexOf(signalOf(b)) || a.pid - b.pid

const MINUTE = 60000
const HOUR = 3600000
const DAY = 86400000

export const lasted = (ms) => {
  if (!(ms >= MINUTE)) return ""
  if (ms < HOUR) return `${Math.floor(ms / MINUTE)}m`
  if (ms < DAY) return `${Math.floor(ms / HOUR)}h`
  return `${Math.floor(ms / DAY)}d`
}

export const waiting = (agent, now) =>
  !agent || signalOf(agent) === "working" ? "" : lasted(now - (agent.updated ?? now))

export const basename = (dir) => (dir || "").replace(/\/+$/, "").split("/").pop() || dir || ""

export const nameOf = (agent) => agent.title || basename(agent.cwd) || agent.kind

export const detailOf = (agent) =>
  [
    agent.kind,
    agent.status?.model,
    typeof agent.status?.contextShare === "number" ? `${Math.round(agent.status.contextShare)}%` : "",
  ]
    .filter(Boolean)
    .join(" · ")

export const isOpen = (agent) => agent.pane !== null && agent.pane !== undefined

export const dirsKnownTo = (scope) => {
  const dirs = []
  for (const place of scope?.places ?? []) if (place.dir) dirs.push(place.dir)
  for (const profile of scope?.shelf ?? []) if (profile.dir && !dirs.includes(profile.dir)) dirs.push(profile.dir)
  return dirs
}

export const homeOf = (scope) => scope?.home ?? ""

export const tilde = (root, dir) => {
  if (!root || !dir) return dir || ""
  if (dir === root) return "~"
  return dir.startsWith(root + "/") ? "~" + dir.slice(root.length) : dir
}

export const placeIn = (scope, project) =>
  (scope?.places ?? []).find((place) => place.project === project) ?? null

export const agentsIn = (scope, project) =>
  (scope?.agents ?? []).filter((agent) => agent.project === project).sort(byUrgency)

export const labelIn = (scope, project) => {
  const place = placeIn(scope, project)
  return place?.name || (place?.dir ? basename(place.dir) : "") || `Project ${project}`
}

export const liveProjects = (scope) => {
  const count = scope?.project_count ?? 9
  const out = []
  for (let project = 1; project <= count; project++) {
    const place = placeIn(scope, project)
    const agents = agentsIn(scope, project)
    if (place || agents.length > 0 || scope?.active === project) out.push({ project, place, agents })
  }
  return out
}

export const tally = (agents) => {
  const counts = { alert: 0, done: 0, working: 0, idle: 0 }
  for (const agent of agents ?? []) counts[signalOf(agent)] += 1
  return counts
}

export const KEPT = 6

export const alike = (a, b) => a.length === b.length && a.every((one, i) => one === b[i])

export const kept = (was, here, live) => {
  const known = [...was, ...live.filter((pane) => !was.includes(pane))]
  const stays = known.filter((pane) => pane !== here && live.includes(pane))
  return (here === undefined ? stays : [here, ...stays]).slice(0, KEPT)
}

export const openAgents = (scope) =>
  (scope?.agents ?? [])
    .filter(isOpen)
    .sort((a, b) => (a.project ?? 0) - (b.project ?? 0) || a.pid - b.pid)

export const summary = (agents) => {
  const counts = tally(agents)
  return [
    counts.alert > 0 ? `${counts.alert} need you` : "",
    counts.done > 0 ? `${counts.done} done` : "",
    counts.working > 0 ? `${counts.working} working` : "",
  ]
    .filter(Boolean)
    .join(" · ")
}
