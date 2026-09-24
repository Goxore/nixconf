export const MODIFIERS = [
  { label: "Ctrl", flag: "ctrl" },
  { label: "Alt", flag: "alt" },
  { label: "Shift", flag: "shift" },
]

export const NEWLINE = "\x1b\r"

const BACKTAB = "\x1b[Z"

export const wantsNewline = (event) =>
  event.type === "keydown" && event.key === "Enter" && event.shiftKey

export const PRESSES = [
  { label: "Esc", code: "\x1b" },
  { label: "Tab", code: "\t" },
  { label: "⏎+", code: NEWLINE },
  { label: "↑", code: "\x1b[A", repeats: true },
  { label: "↓", code: "\x1b[B", repeats: true },
  { label: "←", code: "\x1b[D", repeats: true },
  { label: "→", code: "\x1b[C", repeats: true },
  { label: "Home", code: "\x1b[H" },
  { label: "End", code: "\x1b[F" },
  { label: "PgUp", code: "\x1b[5~" },
  { label: "PgDn", code: "\x1b[6~" },
]

const LETTER = /^[a-z]$/
const MOVE = /^\x1b\[([A-Z])$/
const PAGE = /^\x1b\[(\d+)~$/

export const coded = ({ ctrl, alt, shift }) =>
  1 + (shift ? 1 : 0) + (alt ? 2 : 0) + (ctrl ? 4 : 0)

export const chord = (character, latch) => {
  const code = coded(latch)
  if (code === 1) return character
  if (character === "\t") return latch.shift ? BACKTAB : character

  const move = MOVE.exec(character)
  if (move) return `\x1b[1;${code}${move[1]}`
  const page = PAGE.exec(character)
  if (page) return `\x1b[${page[1]};${code}~`

  const base = character.length === 1 ? character.toLowerCase() : character
  if (!LETTER.test(base)) return character

  const letter = latch.shift ? base.toUpperCase() : base
  if (latch.ctrl) return String.fromCharCode(base.charCodeAt(0) - 96)
  if (latch.alt) return `\x1b${letter}`
  return letter
}
