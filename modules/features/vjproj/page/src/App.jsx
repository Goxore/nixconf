import { Match, Show, Switch, onCleanup, onMount } from "solid-js"
import { Projects } from "#screens/Projects.jsx"
import { Project } from "#screens/Project.jsx"
import { Pane } from "#screens/Pane.jsx"
import { Deck } from "#screens/Deck.jsx"
import { Make } from "#screens/Make.jsx"
import { Dialog, Picker } from "#ui/Sheet.jsx"
import { Empty, Snackbar } from "#ui/Feedback.jsx"
import { Swipeable } from "#ui/Swipeable.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { tick } from "#lib/clock.js"
import { settle } from "#lib/push.js"
import { ripple } from "#lib/ripple.js"
import { askClose, askStart, closing, starting } from "#lib/ask.js"
import { atRoot, complain, inform, popped, retreat, view } from "#lib/nav.js"
import { path, pullState, scope } from "#lib/store.js"
import { send, token } from "#lib/api.js"
import { labelIn, placeIn } from "#lib/model.js"

const STATE_POLL = 1000

const loop = (job, every) => {
  let timer
  const run = async () => {
    if (!document.hidden) await job()
    timer = setTimeout(run, every())
  }
  run()
  onCleanup(() => clearTimeout(timer))
}

const roomFor = (viewport, fallback) => {
  const height = viewport?.height
  return typeof height === "number" && height > 0 ? height : fallback
}

export const App = () => {
  const fit = () => {
    const room = roomFor(window.visualViewport, window.innerHeight)
    document.documentElement.style.setProperty("--room", `${room}px`)
    if (window.scrollY !== 0) window.scrollTo(0, 0)
  }

  const close = () => {
    const pane = closing()
    askClose(null)
    const staying = view().at === "deck"
    send(path(`/pane/${pane}/close`))
      .then(async () => {
        await pullState()
        if (!staying) retreat()
      })
      .catch(() => complain("Could not close it."))
  }

  const start = (kind) => {
    const project = starting()
    const label = labelIn(scope(), project)
    askStart(null)
    send(path("/agent"), { kind, project })
      .then(() => inform(`Starting ${kind} in ${label}`))
      .catch(() => complain("Could not start it."))
  }

  const refresh = async () => {
    tick()
    await pullState()
  }

  onMount(() => {
    fit()
    settle()
    loop(refresh, () => STATE_POLL)

    const wake = () => {
      if (document.hidden) return
      refresh()
    }
    document.addEventListener("visibilitychange", wake)
    document.addEventListener("pointerdown", ripple)
    window.addEventListener("popstate", popped)
    window.addEventListener("resize", fit)
    window.visualViewport?.addEventListener("resize", fit)
    window.visualViewport?.addEventListener("scroll", fit)

    onCleanup(() => {
      document.removeEventListener("visibilitychange", wake)
      document.removeEventListener("pointerdown", ripple)
      window.removeEventListener("popstate", popped)
      window.removeEventListener("resize", fit)
      window.visualViewport?.removeEventListener("resize", fit)
      window.visualViewport?.removeEventListener("scroll", fit)
    })
  })

  return (
    <Show
      when={token()}
      fallback={
        <Empty icon={GLYPHS.signIn} title="Sign in">
          Open the link from <code>vjproj url</code> on this phone.
        </Empty>
      }
    >
      <Swipeable armed={() => !atRoot()} onBack={retreat}>
        <Switch fallback={<Projects />}>
          <Match when={view().at === "pane"}>
            <Pane />
          </Match>
          <Match when={view().at === "deck"}>
            <Deck />
          </Match>
          <Match when={view().at === "project"}>
            <Project />
          </Match>
          <Match when={view().at === "make"}>
            <Make />
          </Match>
        </Switch>
      </Swipeable>

      <Snackbar />

      <Dialog
        when={closing() !== null}
        icon={GLYPHS.remove}
        title="Close this terminal?"
        confirm="Close"
        onDismiss={() => askClose(null)}
        onConfirm={close}
      >
        Whatever is running in it stops.
      </Dialog>

      <Picker
        when={starting() !== null}
        title="Start an agent"
        where={labelIn(scope(), starting())}
        icon={placeIn(scope(), starting())?.icon}
        onDismiss={() => askStart(null)}
        onPick={start}
      />
    </Show>
  )
}
