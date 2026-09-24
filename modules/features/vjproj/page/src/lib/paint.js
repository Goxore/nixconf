export const SHADES = [
  "black",
  "red",
  "green",
  "yellow",
  "blue",
  "magenta",
  "cyan",
  "white",
  "brightBlack",
  "brightRed",
  "brightGreen",
  "brightYellow",
  "brightBlue",
  "brightMagenta",
  "brightCyan",
  "brightWhite",
]

export const themed = (shade) => {
  const theme = {
    background: shade("surface"),
    foreground: shade("ink-surface"),
    cursor: shade("ink-surface"),
    cursorAccent: shade("surface"),
    selectionBackground: shade("surface-container-highest"),
  }
  SHADES.forEach((name, index) => {
    theme[name] = shade(`ansi-${index}`)
  })
  return theme
}

const fromPage = (name) =>
  getComputedStyle(document.documentElement).getPropertyValue(`--${name}`).trim()

export const paint = () => themed(fromPage)
