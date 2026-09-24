import { render } from "solid-js/web"
import { App } from "./App"
import { loadIcons } from "#lib/icons.js"
import "@xterm/xterm/css/xterm.css"
import "./app.css"

loadIcons()

render(() => <App />, document.getElementById("app"))
