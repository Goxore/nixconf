import test from "node:test"
import assert from "node:assert/strict"
import { host } from "./fixtures/stubs.mjs"

const ui = await import("./.built/ui.mjs")

const agent = (over) => ({ pid: 1, kind: "codex", project: 1, activity: "idle", ...over })

const project = (over) => ({
  place: { dir: "/home/yurii/x" },
  agents: [],
  label: "x",
  home: "/home/yurii",
  active: false,
  onOpen: () => {},
  ...over,
})

const rows = (where) => [...where.querySelectorAll(".item")]

test("a project row shows its name and its folder", () => {
  const where = host()
  ui.mountProjectGroup(where, project({ place: { dir: "/home/yurii/nixconf", icon: "code" }, label: "nixconf" }))

  assert.match(where.textContent, /nixconf/)
  assert.match(where.textContent, /~\/nixconf/)
})

test("only the project you are standing in is badged Here", () => {
  const standing = host()
  ui.mountProjectGroup(standing, project({ active: true }))

  const elsewhere = host()
  ui.mountProjectGroup(elsewhere, project())

  assert.equal(standing.querySelectorAll(".here-badge").length, 1)
  assert.equal(standing.querySelectorAll(".avatar.here").length, 1)
  assert.equal(elsewhere.querySelectorAll(".here-badge").length, 0)
})

test("a project name is written as text and can never become markup", () => {
  const where = host()
  ui.mountProjectGroup(where, project({ label: "<img src=x onerror=alert(1)>" }))

  assert.equal(where.querySelectorAll("img").length, 0)
  assert.match(where.textContent, /onerror=alert\(1\)/)
})

test("a project row carries one dot per agent, most urgent first", () => {
  const where = host()
  ui.mountProjectGroup(
    where,
    project({
      agents: [agent({ pid: 1, attention: true, activity: "blocked" }), agent({ pid: 2, activity: "running" })],
    }),
  )

  const dots = [...rows(where)[0].querySelectorAll(".dots .dot")]
  assert.equal(dots.length, 2)
  assert.ok(dots[0].className.includes("alert"))
  assert.ok(rows(where)[0].className.includes("urgent"))
})

test("a busy dot takes the colour of the agent's kind", () => {
  const where = host()
  ui.mountProjectGroup(where, project({ agents: [agent({ kind: "codex", activity: "running" })] }))

  const dot = where.querySelector(".dots .dot")
  assert.ok(dot.className.includes("working"))
  assert.ok(dot.className.includes("codex"))
})

test("a project lists its agents underneath, most urgent first", () => {
  const where = host()
  ui.mountProjectGroup(
    where,
    project({
      agents: [
        agent({ pid: 1, kind: "claude-per", pane: "3", attention: true, activity: "blocked" }),
        agent({ pid: 2, kind: "codex", pane: "4", activity: "running" }),
      ],
    }),
  )

  const nested = rows(where).slice(1)
  assert.equal(nested.length, 2)
  assert.match(nested[0].textContent, /claude-per/)
  assert.match(nested[1].textContent, /codex/)
})

test("a project with no agents lists only itself", () => {
  const where = host()
  ui.mountProjectGroup(where, project())

  assert.equal(rows(where).length, 1)
})

test("tapping a nested agent opens it without opening the project", () => {
  let openedProject = 0
  let openedAgent = null
  const where = host()
  ui.mountProjectGroup(
    where,
    project({
      agents: [agent({ pid: 7, pane: "9" })],
      onOpen: () => (openedProject += 1),
      onOpenAgent: (found) => (openedAgent = found),
    }),
  )

  rows(where)[1].querySelector(".row").click()

  assert.equal(openedProject, 0, "the project page must not be visited on the way")
  assert.equal(openedAgent?.pane, "9")
})

test("the start button names the project it would start in", () => {
  let asked = 0
  let opened = 0
  const where = host()
  ui.mountProjectGroup(
    where,
    project({ label: "nixconf", onOpen: () => (opened += 1), onStart: () => (asked += 1) }),
  )

  const add = rows(where)[0].querySelector(".icon-button")
  assert.equal(add.getAttribute("aria-label"), "Start an agent in nixconf")

  add.click()
  assert.equal(asked, 1)
  assert.equal(opened, 0, "starting an agent must not open the project too")
})

test("the picker offers every kind and hands back the one tapped", () => {
  let picked = ""
  const where = host()
  ui.mountPicker(where, {
    when: true,
    title: "Start an agent",
    where: "devenv",
    onDismiss: () => {},
    onPick: (kind) => (picked = kind),
  })

  assert.match(where.textContent, /devenv/)

  const kinds = [...where.querySelectorAll(".row")]
  assert.deepEqual(
    kinds.map((one) => one.querySelector(".headline").textContent),
    ["claude-per", "claude-fish", "codex", "opencode"],
  )

  kinds[3].click()
  assert.equal(picked, "opencode")
})

test("an agent with no terminal is shown but cannot be opened", () => {
  let opened = 0
  const where = host()
  ui.mountAgentRow(where, { agent: agent({ pane: null }), onOpen: () => (opened += 1) })

  where.querySelector(".row").click()

  assert.equal(opened, 0)
  assert.ok(where.querySelector(".item").className.includes("quiet"))
  assert.equal(where.querySelector(".row").getAttribute("aria-disabled"), "true")
})

test("an agent holding a terminal opens when tapped", () => {
  let opened = 0
  const where = host()
  ui.mountAgentRow(where, { agent: agent({ pane: "5" }), onOpen: () => (opened += 1) })

  where.querySelector(".row").click()

  assert.equal(opened, 1)
})

test("an agent that is waiting says what it is asking for, in place of its details", () => {
  const where = host()
  ui.mountAgentRow(where, {
    agent: agent({
      pane: "5",
      attention: true,
      activity: "blocked",
      notice: "Claude needs your permission to run git push",
      status: { model: "sonnet", contextShare: 42 },
    }),
    onOpen: () => {},
  })

  assert.match(where.textContent, /needs your permission to run git push/)
  assert.equal(where.querySelectorAll(".supporting.asking").length, 1)
  assert.doesNotMatch(where.textContent, /sonnet/, "the question crowds out the model and context")
})

test("an agent with nothing to ask keeps showing its kind and model", () => {
  const where = host()
  ui.mountAgentRow(where, {
    agent: agent({ pane: "5", notice: "", status: { model: "sonnet", contextShare: 42 } }),
    onOpen: () => {},
  })

  assert.match(where.textContent, /codex · sonnet · 42%/)
  assert.equal(where.querySelectorAll(".supporting.asking").length, 0)
})

test("an agent's status chip says how it is doing and for how long", () => {
  const where = host()
  ui.mountAgentRow(where, {
    agent: agent({ pane: "5", attention: true, activity: "blocked", updated: Date.now() - 3.5 * 3600000 }),
    onOpen: () => {},
  })

  const chip = where.querySelector(".signal")
  assert.ok(chip.className.includes("alert"))
  assert.match(chip.textContent, /Needs you/)
  assert.match(chip.textContent, /3h/)
})

test("a question from an agent is written as text and can never become markup", () => {
  const where = host()
  ui.mountAgentRow(where, {
    agent: agent({ pane: "5", notice: "<img src=x onerror=alert(1)>" }),
    onOpen: () => {},
  })

  assert.equal(where.querySelectorAll("img").length, 0)
  assert.match(where.textContent, /<img src=x/)
})

test("a machine row counts the agents running over there", () => {
  const where = host()
  ui.mountMachineRow(where, {
    peer: { host: "mini", state: { agents: [agent({ pid: 1 }), agent({ pid: 2 })] } },
    onOpen: () => {},
  })

  assert.match(where.textContent, /mini/)
  assert.match(where.textContent, /2 agents/)
  assert.equal(where.querySelectorAll(".dots .dot").length, 2)
})

test("the terminal keeps the box it painted into when the status changes", () => {
  const where = host()
  const [waiting, setWaiting] = ui.signal(true)
  const box = ui.mountScreen(where, waiting)

  const painted = document.createElement("div")
  painted.className = "xterm"
  box().append(painted)

  setWaiting(false)
  assert.equal(box().querySelector(".xterm"), painted, "the terminal was wiped by a status change")

  setWaiting(true)
  assert.equal(box().querySelector(".xterm"), painted, "the terminal was wiped when the status came back")
})

test("the notification row is a switch that follows the browser's standing", () => {
  let toggled = 0
  const off = host()
  ui.mountNotifyRow(off, { standing: "off", onToggle: () => (toggled += 1) })
  const button = off.querySelector(".row")
  assert.equal(button.getAttribute("role"), "switch")
  assert.equal(button.getAttribute("aria-checked"), "false")
  button.click()
  assert.equal(toggled, 1)

  const on = host()
  ui.mountNotifyRow(on, { standing: "on", onToggle: () => {} })
  assert.equal(on.querySelector(".row").getAttribute("aria-checked"), "true")
  assert.equal(on.querySelectorAll(".switch.on").length, 1)
})

test("a browser that refuses notifications says so and cannot be tapped", () => {
  let toggled = 0
  const where = host()
  ui.mountNotifyRow(where, { standing: "blocked", onToggle: () => (toggled += 1) })

  where.querySelector(".row").click()

  assert.match(where.textContent, /Blocked by this browser/)
  assert.equal(toggled, 0)
  assert.equal(where.querySelector(".row").getAttribute("aria-disabled"), "true")
})

test("a browser that cannot do notifications at all is offered nothing", () => {
  const where = host()
  ui.mountNotifyRow(where, { standing: "unsupported", onToggle: () => {} })
  assert.equal(where.querySelectorAll(".row").length, 0)

  const waiting = host()
  ui.mountNotifyRow(waiting, { standing: "unknown", onToggle: () => {} })
  assert.equal(waiting.querySelectorAll(".row").length, 0)
})

test("the server's signing key is unpacked from base64url, padding and all", () => {
  const urlish = (raw) =>
    btoa(String.fromCharCode(...raw))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "")

  for (const length of [1, 2, 3, 65]) {
    const raw = Array.from({ length }, (_, i) => (i * 37 + 251) % 256)
    assert.deepEqual([...ui.bytesOf(urlish(raw))], raw, `a ${length} byte key survives the trip`)
  }

  assert.ok(
    urlish([0xfb, 0xff, 0x3e]).includes("-") || urlish([0xfb, 0xff, 0x3e]).includes("_"),
    "the sample really does exercise the url alphabet",
  )
  assert.equal(ui.bytesOf("").length, 0)
  assert.equal(ui.supported(), false, "a page with no service worker offers no notifications")
})
