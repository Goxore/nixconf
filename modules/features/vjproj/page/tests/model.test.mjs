import test from "node:test"
import assert from "node:assert/strict"
import {
  agentsIn,
  basename,
  dirsKnownTo,
  homeOf,
  detailOf,
  isOpen,
  labelIn,
  lasted,
  liveProjects,
  nameOf,
  openAgents,
  summary,
  signalOf,
  tilde,
  waiting,
} from "#lib/model.js"

const agent = (over) => ({ pid: 1, kind: "codex", project: 1, activity: "idle", ...over })

const scope = {
  active: 2,
  project_count: 9,
  places: [
    { project: 1, name: "nixconf", dir: "/home/yurii/nixconf", icon: "code" },
    { project: 2, dir: "/home/yurii/cachix" },
  ],
  shelf: [{ id: 7, name: "old", dir: "/home/yurii/old" }],
  agents: [
    agent({ pid: 10, project: 1, activity: "idle" }),
    agent({ pid: 11, project: 1, attention: true, activity: "blocked" }),
    agent({ pid: 12, project: 2, activity: "running", pane: "5" }),
  ],
}

test("an agent waiting on you outranks one that is merely busy", () => {
  assert.equal(signalOf({ attention: true, activity: "blocked" }), "alert")
  assert.equal(signalOf({ attention: true, activity: "running" }), "done")
  assert.equal(signalOf({ activity: "running" }), "working")
  assert.equal(signalOf({ activity: "idle" }), "idle")
})

test("the agent needing you is listed first", () => {
  assert.deepEqual(
    agentsIn(scope, 1).map((one) => one.pid),
    [11, 10],
  )
})

test("a project is named by its label, then its folder, then its number", () => {
  assert.equal(labelIn(scope, 1), "nixconf")
  assert.equal(labelIn(scope, 2), "cachix")
  assert.equal(labelIn(scope, 5), "Project 5")
})

test("only projects with something in them are listed", () => {
  assert.deepEqual(
    liveProjects(scope).map((one) => one.project),
    [1, 2],
  )
})

test("the project you are standing in is listed even when it is empty", () => {
  const bare = { active: 4, project_count: 9, places: [], agents: [] }
  assert.deepEqual(
    liveProjects(bare).map((one) => one.project),
    [4],
  )
})

test("a machine we know nothing about lists no projects", () => {
  assert.deepEqual(liveProjects(null), [])
  assert.deepEqual(agentsIn(null, 1), [])
  assert.equal(labelIn(null, 3), "Project 3")
})

test("home is whatever the machine says it is", () => {
  assert.equal(homeOf({ home: "/home/yurii" }), "/home/yurii")
  assert.equal(homeOf(scope), "")
  assert.equal(homeOf(null), "")
})

test("paths inside home shorten to a tilde", () => {
  assert.equal(tilde("/home/yurii", "/home/yurii/nixconf"), "~/nixconf")
  assert.equal(tilde("/home/yurii", "/home/yurii"), "~")
  assert.equal(tilde("/home/yurii", "/etc/nixos"), "/etc/nixos")
})

test("a folder that merely starts with the same letters is not shortened", () => {
  assert.equal(tilde("/home/yurii", "/home/yuriiwork"), "/home/yuriiwork")
})

test("only agents holding a terminal can be opened", () => {
  assert.equal(isOpen({ pane: "5" }), true)
  assert.equal(isOpen({ pane: null }), false)
  assert.equal(isOpen({}), false)
  assert.deepEqual(
    openAgents(scope).map((one) => one.pid),
    [12],
  )
})

test("the deck keeps a settled order so an agent never swaps under your thumb", () => {
  const busy = { ...scope, agents: scope.agents.map((one) => ({ ...one, pane: String(one.pid) })) }
  const before = openAgents(busy).map((one) => one.pid)
  const stirred = {
    ...busy,
    agents: busy.agents.map((one) => ({ ...one, attention: one.pid === 12, activity: "blocked" })),
  }
  assert.deepEqual(openAgents(stirred).map((one) => one.pid), before)
  assert.deepEqual(before, [10, 11, 12], "settled means by project, then by age")
})

test("how long an agent has been waiting reads in one unit", () => {
  assert.equal(lasted(0), "", "a fresh agent carries no duration")
  assert.equal(lasted(59_000), "", "under a minute is not worth saying")
  assert.equal(lasted(60_000), "1m")
  assert.equal(lasted(12 * 60_000), "12m")
  assert.equal(lasted(60 * 60_000), "1h")
  assert.equal(lasted(25 * 3_600_000), "1d")
  assert.equal(lasted(-5000), "", "a clock that ran backwards says nothing")
})

test("only an agent that has stopped shows how long it has been that way", () => {
  const now = 10_000_000
  const since = (over) => waiting({ updated: now - 12 * 60_000, ...over }, now)

  assert.equal(since({ attention: true, activity: "blocked" }), "12m", "needs you for twelve minutes")
  assert.equal(since({ attention: true, activity: "running" }), "12m", "done twelve minutes ago")
  assert.equal(since({ activity: "idle" }), "12m")
  assert.equal(since({ activity: "running" }), "", "a working agent has no duration to give")
  assert.equal(waiting({ activity: "idle" }, now), "", "an agent with no timestamp says nothing")
  assert.equal(waiting(undefined, now), "", "and neither does a missing agent")
})

test("an agent falls back to its folder and then its kind for a name", () => {
  assert.equal(nameOf({ title: "fix the bug", cwd: "/home/yurii/x", kind: "codex" }), "fix the bug")
  assert.equal(nameOf({ cwd: "/home/yurii/nixconf", kind: "codex" }), "nixconf")
  assert.equal(nameOf({ kind: "codex" }), "codex")
})

test("the folder list for a new project covers places and the shelf", () => {
  assert.deepEqual(dirsKnownTo(scope), [
    "/home/yurii/nixconf",
    "/home/yurii/cachix",
    "/home/yurii/old",
  ])
})

test("a trailing slash never changes a folder name", () => {
  assert.equal(basename("/home/yurii/nixconf/"), "nixconf")
  assert.equal(basename(""), "")
})

test("an agent's details read kind, model and context in one line", () => {
  assert.equal(detailOf({ kind: "codex", status: { model: "gpt", contextShare: 41.6 } }), "codex · gpt · 42%")
  assert.equal(detailOf({ kind: "codex" }), "codex")
  assert.equal(detailOf({ kind: "codex", status: { contextShare: 0 } }), "codex · 0%")
})

test("the headline counts only the agents worth mentioning", () => {
  assert.equal(summary(scope.agents), "1 need you · 1 working")
  assert.equal(summary([]), "")
  assert.equal(summary(undefined), "")
})
