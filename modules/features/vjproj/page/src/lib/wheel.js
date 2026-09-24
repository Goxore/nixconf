const UP = 64
const DOWN = 65

const NOTCH = 3
const FRAME = 16
const DECAY = 0.95
const BLEND = 0.6
const FLICK = 0.35
const SPENT = 0.06

export const STALE = 90

export const watching = (modes) => (modes?.mouseTrackingMode ?? "none") !== "none"

const within = (value, most) => Math.min(Math.max(value, 1), Math.max(most, 1))

export const cellAt = (spot, size, at) => {
  if (!spot?.width || !spot?.height) return { col: 1, row: 1 }
  return {
    col: within(Math.floor(((at.x - spot.left) / spot.width) * size.cols) + 1, size.cols),
    row: within(Math.floor(((at.y - spot.top) / spot.height) * size.rows) + 1, size.rows),
  }
}

export const wheels = (rows, cell) =>
  `\x1b[<${rows < 0 ? UP : DOWN};${cell.col};${cell.row}M`.repeat(Math.abs(rows))

export const stride = (cell, tracking) => Math.max(cell, 1) * (tracking ? NOTCH : 1)

export const notches = (travel, gap) => Math.trunc(travel / gap) || 0

export const paced = (speed, travel, ms) => {
  if (!(ms > 0)) return speed
  const now = travel / ms
  return speed === 0 ? now : speed * (1 - BLEND) + now * BLEND
}

export const eased = (speed, ms) => speed * DECAY ** (ms / FRAME)

export const flicked = (speed) => Math.abs(speed) >= FLICK

export const drifting = (speed) => Math.abs(speed) >= SPENT
