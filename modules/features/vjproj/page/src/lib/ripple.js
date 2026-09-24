const LIFE = 550

export const ripple = (event) => {
  const host = event.target.closest?.(".pressable")
  if (!host || host.disabled || host.getAttribute("aria-disabled") === "true") return
  const box = host.getBoundingClientRect()
  const size = Math.hypot(box.width, box.height) * 2
  const wave = document.createElement("span")
  wave.className = "ripple"
  wave.style.width = wave.style.height = `${size}px`
  wave.style.left = `${event.clientX - box.left - size / 2}px`
  wave.style.top = `${event.clientY - box.top - size / 2}px`
  host.append(wave)
  setTimeout(() => wave.remove(), LIFE)
}
