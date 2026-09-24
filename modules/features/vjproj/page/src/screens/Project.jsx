import { For, Show } from "solid-js"
import { Button, Fab } from "#ui/Button.jsx"
import { Page, Back } from "#ui/Page.jsx"
import { Section, ListGroup } from "#ui/List.jsx"
import { Empty } from "#ui/Feedback.jsx"
import { AgentRow } from "#ui/Agents.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { complain, goto, inform, view } from "#lib/nav.js"
import { askStart } from "#lib/ask.js"
import { path, scope } from "#lib/store.js"
import { send } from "#lib/api.js"
import { agentsIn, homeOf, labelIn, placeIn, tilde } from "#lib/model.js"

export const Project = () => {
  const project = () => view().project
  const place = () => placeIn(scope(), project())
  const agents = () => agentsIn(scope(), project())
  const label = () => labelIn(scope(), project())

  const openShell = () =>
    send(path("/shell"), { project: project() })
      .then(({ pane }) => goto("pane", { pane, pid: null, shell: project(), label: label() }))
      .catch(() => complain("Could not open a shell."))

  const goHere = () =>
    send(path(`/project/${project()}`))
      .then(() => inform(`Switched to ${label()}`))
      .catch(() => complain("Could not switch."))

  return (
    <Page
      leading={<Back />}
      title={label()}
      subtitle={tilde(homeOf(scope()), place()?.dir ?? "")}
      fab={
        <Fab icon={GLYPHS.add} onClick={() => askStart(project())}>
          Start an agent
        </Fab>
      }
    >
      <div class="button-row">
        <Button variant="tonal" icon={GLYPHS.desktop} onClick={goHere}>
          Show on desktop
        </Button>
        <Button variant="tonal" icon={GLYPHS.shell} onClick={openShell}>
          Shell
        </Button>
      </div>

      <Show
        when={agents().length > 0}
        fallback={<Empty icon={GLYPHS.agents} title="No agents in this project." />}
      >
        <Section title="Agents">
          <ListGroup>
            <For each={agents()}>
              {(agent) => <AgentRow agent={agent} onOpen={() => goto("pane", { pane: agent.pane, pid: agent.pid })} />}
            </For>
          </ListGroup>
        </Section>
      </Show>
    </Page>
  )
}
