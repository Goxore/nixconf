import test from "node:test"
import assert from "node:assert/strict"
import { upFrom } from "#lib/nav.js"

const root = { at: "projects" }

test("a screen you drilled into returns to where you came from", () => {
  const projects = { at: "projects" }
  const project = { at: "project", project: 3, from: projects }

  assert.equal(upFrom(project), projects)
})

test("leaving a project on another machine returns to that machine", () => {
  const remote = { at: "project", project: 3, machine: "mini" }

  assert.deepEqual(upFrom(remote), { at: "projects", machine: "mini" })
})

test("leaving another machine's list comes all the way home", () => {
  assert.deepEqual(upFrom({ at: "projects", machine: "mini" }), root)
})

test("the top of the app has nowhere further to go", () => {
  assert.deepEqual(upFrom(root), root)
})

test("a terminal opened from a project goes back to that project", () => {
  const project = { at: "project", project: 3 }
  const pane = { at: "pane", pane: "5", from: project }

  assert.equal(upFrom(pane), project)
})

test("a terminal opened on another machine keeps that machine in view", () => {
  const project = { at: "project", project: 3, machine: "mini" }
  const pane = { at: "pane", pane: "5", machine: "mini", from: project }

  assert.equal(upFrom(pane), project)
  assert.equal(upFrom(pane).machine, "mini")
})

test("a complaint fades on its own so it never sits there stale", async () => {
  const { mock } = await import("node:test")
  const { complain, hush, oops } = await import("../src/lib/nav.js")

  mock.timers.enable({ apis: ["setTimeout"] })
  try {
    complain("Could not send that.")
    assert.equal(oops(), "Could not send that.")

    mock.timers.tick(5000)
    assert.equal(oops(), "Could not send that.", "it stays long enough to be read")

    mock.timers.tick(2000)
    assert.equal(oops(), "", "and then it clears itself")

    complain("Could not start it.")
    hush()
    assert.equal(oops(), "", "moving on clears it at once")
    mock.timers.tick(10000)
    assert.equal(oops(), "", "and the fade never fires late over a fresh screen")
  } finally {
    mock.timers.reset()
  }
})

test("a screen that replaces another leaves no dead step behind the back button", async () => {
  const steps = []
  globalThis.history = {
    pushState: () => steps.push("push"),
    replaceState: () => steps.push("replace"),
  }
  const { goto, view } = await import("../src/lib/nav.js")

  goto("make")
  goto("project", { project: 4 }, { replace: true })

  assert.deepEqual(steps, ["push", "replace"])
  assert.equal(view().at, "project")
  assert.deepEqual(upFrom(view()), root, "back from the new project lands on the list, not the form")
})
