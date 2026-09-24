import { onCleanup, onMount } from "solid-js"
import { EDGE, drag, settles } from "#lib/gesture.js"

const SPRING = "transform .2s ease-out, opacity .2s ease-out"
const LEAVE = 170

export const Swipeable = (props) => {
  let node

  const rest = () => {
    node.style.transition = SPRING
    node.style.transform = ""
    node.style.opacity = ""
  }

  onMount(() => {
    const stop = drag(node, {
      accepts: (touch) => props.armed() && touch.clientX <= EDGE,
      onMove: (dx) => {
        const shift = Math.max(0, dx)
        node.style.transition = "none"
        node.style.transform = `translateX(${shift}px)`
        node.style.opacity = String(Math.max(0.35, 1 - shift / (window.innerWidth || 1)))
      },
      onEnd: (dx, ms) => {
        node.style.transition = SPRING
        if (!settles(dx, window.innerWidth, ms)) return rest()
        navigator.vibrate?.(10)
        node.style.transform = "translateX(100%)"
        node.style.opacity = "0"
        setTimeout(() => {
          rest()
          props.onBack()
        }, LEAVE)
      },
    })
    onCleanup(stop)
  })

  return (
    <div class="swipe" ref={node}>
      {props.children}
    </div>
  )
}
