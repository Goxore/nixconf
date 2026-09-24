import test from "node:test"
import assert from "node:assert/strict"
import { chord, coded, wantsNewline, NEWLINE, PRESSES, MODIFIERS } from "#lib/keys.js"

const none = { ctrl: false, alt: false, shift: false }
const ctrl = { ctrl: true, alt: false, shift: false }
const alt = { ctrl: false, alt: true, shift: false }
const shift = { ctrl: false, alt: false, shift: true }

test("an unlatched key goes through untouched", () => {
  assert.equal(chord("c", none), "c")
  assert.equal(chord("\r", none), "\r")
})

test("a latched ctrl turns a letter into its control byte", () => {
  assert.equal(chord("c", ctrl), "\x03")
  assert.equal(chord("d", ctrl), "\x04")
  assert.equal(chord("l", ctrl), "\x0c")
})

test("a capital letter still latches to the lowercase control byte", () => {
  assert.equal(chord("C", ctrl), "\x03")
})

test("a latched alt puts an escape in front of the letter", () => {
  assert.equal(chord("b", alt), "\x1bb")
})

test("a latched shift capitalises a letter, on its own or alongside alt", () => {
  assert.equal(chord("c", shift), "C")
  assert.equal(chord("C", shift), "C")
  assert.equal(chord("b", { ctrl: false, alt: true, shift: true }), "\x1bB")
  assert.equal(chord("c", { ctrl: true, alt: false, shift: true }), "\x03", "ctrl still interrupts")
})

test("a latched shift turns tab into a back tab", () => {
  assert.equal(chord("\t", shift), "\x1b[Z")
  assert.equal(chord("\t", none), "\t")
  assert.equal(chord("\t", ctrl), "\t", "only shift has anything to say about tab")
})

test("a latched modifier rides along on the arrows and the page keys", () => {
  assert.equal(chord("\x1b[A", shift), "\x1b[1;2A")
  assert.equal(chord("\x1b[C", ctrl), "\x1b[1;5C", "ctrl and an arrow steps over a word")
  assert.equal(chord("\x1b[H", alt), "\x1b[1;3H")
  assert.equal(chord("\x1b[5~", shift), "\x1b[5;2~")
  assert.equal(chord("\x1b[6~", ctrl), "\x1b[6;5~")
  assert.equal(chord("\x1b[A", none), "\x1b[A", "a bare arrow is left alone")
})

test("the modifier a terminal is told about counts shift, alt and ctrl in that order", () => {
  assert.equal(coded(none), 1)
  assert.equal(coded(shift), 2)
  assert.equal(coded(alt), 3)
  assert.equal(coded(ctrl), 5)
  assert.equal(coded({ ctrl: true, alt: true, shift: true }), 8)
})

test("a latched modifier leaves the plain keys alone", () => {
  assert.equal(chord("\r", ctrl), "\r")
  assert.equal(chord("\x1b", shift), "\x1b")
  assert.equal(chord(NEWLINE, shift), NEWLINE)
})

test("a latched modifier never invents a key out of punctuation", () => {
  assert.equal(chord(";", ctrl), ";")
  assert.equal(chord("1", ctrl), "1")
  assert.equal(chord(";", shift), ";")
})

test("ctrl, alt and shift are the latches offered", () => {
  assert.deepEqual(
    MODIFIERS.map((one) => one.flag),
    ["ctrl", "alt", "shift"],
  )
  assert.deepEqual(
    MODIFIERS.map((one) => one.label),
    ["Ctrl", "Alt", "Shift"],
  )
})

test("every key in the row sends a real terminal sequence", () => {
  for (const one of PRESSES) {
    assert.equal(typeof one.code, "string")
    assert.ok(one.code.length > 0, `${one.label} sends nothing`)
  }
})

test("the arrows send the sequences a terminal expects", () => {
  const bylabel = Object.fromEntries(PRESSES.map((one) => [one.label, one.code]))
  assert.equal(bylabel["↑"], "\x1b[A")
  assert.equal(bylabel["↓"], "\x1b[B")
  assert.equal(bylabel["←"], "\x1b[D")
  assert.equal(bylabel["→"], "\x1b[C")
})

test("the page keys sit at the far end, out of the way of the ones in daily use", () => {
  assert.deepEqual(
    PRESSES.slice(-2).map((one) => one.label),
    ["PgUp", "PgDn"],
  )
})

test("only the arrows repeat when held", () => {
  const repeating = PRESSES.filter((one) => one.repeats).map((one) => one.label)
  assert.deepEqual(repeating, ["↑", "↓", "←", "→"])
})

test("shift and enter asks for a newline, plain enter does not", () => {
  const press = (over) => ({ type: "keydown", key: "Enter", shiftKey: false, ...over })
  assert.equal(wantsNewline(press({ shiftKey: true })), true)
  assert.equal(wantsNewline(press({})), false, "a bare Enter must still submit")
  assert.equal(wantsNewline(press({ key: "a", shiftKey: true })), false)
  assert.equal(
    wantsNewline(press({ shiftKey: true, type: "keyup" })),
    false,
    "the release must not send a second newline",
  )
})

test("a newline is the escape and carriage return claude code binds shift+enter to", () => {
  assert.deepEqual([...new TextEncoder().encode(NEWLINE)], [0x1b, 0x0d])
})

test("the key bar carries a newline key that sends the same bytes as shift+enter", () => {
  const key = PRESSES.find((one) => one.label === "⏎+")
  assert.ok(key, "the key bar must offer a newline on a touch keyboard")
  assert.equal(key.code, NEWLINE)
  assert.ok(!key.repeats, "holding it must not spray newlines")
})

test("a latched modifier turns the next character typed into the terminal into a control byte", async () => {
  const { ctrl, alt, shift, held, latched, pressed, toggle, unlatch } = await import(
    "../src/lib/latch.js"
  )

  assert.equal(held(), false, "nothing is latched to begin with")
  assert.equal(chord("c", latched()), "c", "an unlatched c is just a c")

  toggle("ctrl")
  assert.equal(ctrl(), true)
  assert.equal(pressed("ctrl"), true, "the key bar shows which latch is down")
  assert.equal(held(), true)
  assert.equal(chord("c", latched()), "\x03", "ctrl+c must still interrupt")

  unlatch()
  assert.equal(held(), false, "a latch lasts exactly one keystroke")
  assert.equal(chord("c", latched()), "c")

  toggle("alt")
  assert.equal(alt(), true)
  assert.equal(chord("b", latched()), "\x1bb")
  unlatch()

  toggle("shift")
  assert.equal(shift(), true)
  assert.equal(pressed("shift"), true)
  assert.equal(held(), true, "a shift on its own still counts as a latch")
  assert.equal(chord("\t", latched()), "\x1b[Z")
  unlatch()
  assert.equal(shift(), false, "letting go clears every latch")
})

test("a drag scrolls by sending wheel presses where the finger is", async () => {
  const { watching, cellAt, wheels } = await import("../src/lib/wheel.js")

  assert.equal(watching(undefined), false, "a plain terminal has no mouse to report to")
  assert.equal(watching({ mouseTrackingMode: "none" }), false)
  assert.equal(watching({ mouseTrackingMode: "vt200" }), true, "tmux with mouse on wants the wheel")

  const spot = { left: 0, top: 0, width: 800, height: 400 }
  const size = { cols: 80, rows: 40 }
  assert.deepEqual(cellAt(spot, size, { x: 0, y: 0 }), { col: 1, row: 1 })
  assert.deepEqual(cellAt(spot, size, { x: 405, y: 205 }), { col: 41, row: 21 })
  assert.deepEqual(
    cellAt(spot, size, { x: 9999, y: 9999 }),
    { col: 80, row: 40 },
    "a finger past the edge still names a cell inside the pane",
  )

  assert.equal(wheels(-1, { col: 4, row: 7 }), "\x1b[<64;4;7M", "back through history is button 64")
  assert.equal(wheels(1, { col: 4, row: 7 }), "\x1b[<65;4;7M", "forward is button 65")
  assert.equal(wheels(-3, { col: 1, row: 1 }), "\x1b[<64;1;1M".repeat(3))
  assert.equal(wheels(0, { col: 1, row: 1 }), "", "a drag too small to cross a row sends nothing")
})

test("the screen moves by as far as the finger moved, and no further", async () => {
  const { stride, notches } = await import("../src/lib/wheel.js")

  assert.equal(stride(14, false), 14, "a terminal we scroll ourselves gives a row per row of finger")
  assert.equal(stride(14, true), 42, "an app reading the wheel takes one press per three rows")
  assert.equal(stride(0, false), 1, "a pane too small to measure never divides by nothing")

  assert.equal(notches(13, 14), 0, "half a row of finger moves nothing")
  assert.equal(notches(28, 14), 2)
  assert.equal(notches(-13, 14), 0)
  assert.equal(notches(-28, 14), -2, "a drag the other way scrolls the other way")
})

test("a flick carries on and then settles", async () => {
  const { paced, eased, flicked, drifting, STALE } = await import("../src/lib/wheel.js")

  assert.equal(paced(0, 20, 10), 2, "the first sample is taken as it comes")
  assert.ok(paced(2, 0, 10) < 2, "a finger slowing down brings the pace down")
  assert.equal(paced(2, 40, 0), 2, "two samples at the same instant tell us nothing new")

  assert.equal(flicked(0.1), false, "letting go slowly leaves the screen where it is")
  assert.equal(flicked(2), true)

  assert.ok(eased(2, 16) < 2, "a glide loses pace every frame")
  assert.ok(drifting(eased(2, 16)))
  assert.equal(drifting(0.01), false)

  let speed = 2
  let frames = 0
  while (drifting(speed) && frames < 1000) {
    speed = eased(speed, 16)
    frames += 1
  }
  assert.ok(frames < 120, `a flick runs out inside two seconds, took ${frames} frames`)
  assert.ok(STALE > 0, "a finger that rests before lifting must not fling")
})

test("the deck opens every agent at once and stays on them", async () => {
  const { kept, alike, KEPT } = await import("../src/lib/model.js")

  assert.deepEqual(kept([], "7", ["7", "9"]), ["7", "9"], "the whole deck comes up together")
  assert.deepEqual(kept(["7", "9"], "9", ["7", "9"]), ["9", "7"], "stepping over reopens nothing")
  assert.deepEqual(kept(["9", "7"], "7", ["7", "9"]), ["7", "9"], "and neither does stepping back")
  assert.deepEqual(kept(["9", "7"], "9", ["9"]), ["9"], "an agent that has gone is let go of")
  assert.deepEqual(kept(["9"], undefined, []), [], "an empty deck holds nothing open")

  const many = Array.from({ length: KEPT + 4 }, (_, i) => String(i))
  const most = kept([], many[0], many)
  assert.equal(most.length, KEPT, "no more terminals than the machine will hand out")
  assert.equal(most[0], many[0], "the agent on screen is never the one dropped")
  assert.deepEqual(
    kept(most, many[KEPT + 1], many)[0],
    many[KEPT + 1],
    "reaching past them opens the one asked for",
  )

  assert.equal(alike(["1", "2"], ["1", "2"]), true)
  assert.equal(alike(["1", "2"], ["2", "1"]), false)
  assert.equal(alike(["1"], ["1", "2"]), false)
})
