import test from "node:test"
import assert from "node:assert/strict"
import { leans, nudged, settles, slipped, COMMIT } from "#lib/gesture.js"

test("a still finger on a key is a tap", () => {
  assert.equal(slipped(0, 0, 10), false)
  assert.equal(slipped(4, 3, 10), false)
})

test("a finger dragged along the key row is scrolling, not a tap", () => {
  assert.equal(slipped(40, 0, 10), true)
  assert.equal(slipped(-40, 0, 10), true)
})

test("a finger dragged off a key vertically is not a tap either", () => {
  assert.equal(slipped(0, 30, 10), true)
})

test("a mostly sideways drag is a swipe", () => {
  assert.equal(leans(60, 5), true)
  assert.equal(leans(-60, 5), true)
})

test("a mostly upward drag is scrolling, not swiping", () => {
  assert.equal(leans(10, 60), false)
  assert.equal(leans(30, 30), false)
})

test("a twitch is neither", () => {
  assert.equal(leans(4, 2), false)
})

test("dragging a third of the way across goes back", () => {
  assert.equal(settles(360, 1000, 500), true)
  assert.equal(settles(COMMIT * 1000, 1000, 500), true)
})

test("a short slow drag springs back instead", () => {
  assert.equal(settles(80, 1000, 500), false)
})

test("a quick flick goes back even when it is short", () => {
  assert.equal(settles(120, 1000, 100), true)
})

test("a swipe on a zero width screen never commits", () => {
  assert.equal(settles(100, 0, 100), false)
})

test("a nudge reports which way you went", () => {
  assert.equal(nudged(80, 1000), 1)
  assert.equal(nudged(-80, 1000), -1)
  assert.equal(nudged(3, 1000), 0)
})
