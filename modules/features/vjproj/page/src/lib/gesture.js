export const EDGE = 32
export const SLOP = 12
export const COMMIT = 0.32
export const FLING = 0.45

export const leans = (dx, dy) => Math.abs(dx) > Math.abs(dy) * 1.4 && Math.abs(dx) > SLOP

export const slipped = (dx, dy, slip) => Math.abs(dx) > slip || Math.abs(dy) > slip

export const settles = (dx, width, ms) => {
  if (width <= 0) return false
  if (dx / width >= COMMIT) return true
  return ms > 0 && dx / ms >= FLING
}

export const nudged = (dx, width) => {
  if (width <= 0 || Math.abs(dx) < SLOP) return 0
  return dx > 0 ? 1 : -1
}

export const drag = (node, plan) => {
  let from = null
  let decided = false

  const start = (event) => {
    if (event.touches.length !== 1) return (from = null)
    const touch = event.touches[0]
    if (!plan.accepts(touch, node)) return (from = null)
    from = { x: touch.clientX, y: touch.clientY, at: event.timeStamp }
    decided = false
  }

  const move = (event) => {
    if (!from || event.touches.length !== 1) return
    const touch = event.touches[0]
    const dx = touch.clientX - from.x
    const dy = touch.clientY - from.y

    if (!decided) {
      if (Math.abs(dx) < SLOP && Math.abs(dy) < SLOP) return
      if (!leans(dx, dy)) return (from = null)
      decided = true
    }
    event.preventDefault()
    plan.onMove?.(dx)
  }

  const end = (event) => {
    if (!from) return
    const held = from
    from = null
    if (!decided) return
    decided = false
    const touch = event.changedTouches?.[0]
    const dx = touch ? touch.clientX - held.x : 0
    plan.onEnd?.(dx, event.timeStamp - held.at)
  }

  node.addEventListener("touchstart", start, { passive: true })
  node.addEventListener("touchmove", move, { passive: false })
  node.addEventListener("touchend", end, { passive: true })
  node.addEventListener("touchcancel", end, { passive: true })

  return () => {
    node.removeEventListener("touchstart", start)
    node.removeEventListener("touchmove", move)
    node.removeEventListener("touchend", end)
    node.removeEventListener("touchcancel", end)
  }
}
