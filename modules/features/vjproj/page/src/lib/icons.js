import { createSignal } from "solid-js"

const [icons, setIcons] = createSignal({})

export { icons }

export const loadIcons = () =>
  fetch("icons.json")
    .then((response) => response.json())
    .then((map) => setIcons(map))
    .catch(() => {})
