import { For, Show } from "solid-js"
import { Icon } from "#ui/Icon.jsx"
import { Fab, IconButton } from "#ui/Button.jsx"
import { Page, Back } from "#ui/Page.jsx"
import { Section, ListGroup } from "#ui/List.jsx"
import { Empty } from "#ui/Feedback.jsx"
import { MachineRow, NOTIFY, NotifyRow, ProjectGroup, ShelfRow } from "#ui/Places.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { complain, goto, view } from "#lib/nav.js"
import { askStart } from "#lib/ask.js"
import { disable, enable, standing } from "#lib/push.js"
import { peers, reachable, scope, path, pullState } from "#lib/store.js"
import { send } from "#lib/api.js"
import { homeOf, isOpen, labelIn, liveProjects, summary } from "#lib/model.js"

export const Projects = () => {
  const live = () => liveProjects(scope())
  const shelf = () => scope()?.shelf ?? []
  const others = () => (view().machine ? [] : peers())
  const home = () => homeOf(scope())
  const open = () => (scope()?.agents ?? []).filter(isOpen).length
  const bare = () => live().length === 0 && shelf().length === 0 && others().length === 0

  const ring = () =>
    (standing() === "on" ? disable() : enable()).catch(() => complain("Could not change notifications."))

  const adopt = (profile) =>
    send(path(`/shelf/${profile.id}`))
      .then(async ({ project }) => {
        await pullState()
        goto("project", { project })
      })
      .catch(() => complain("Could not open it."))

  return (
    <Page
      leading={
        <Show when={view().machine} fallback={<span class="brand"><Icon name={GLYPHS.agents} filled /></span>}>
          <Back />
        </Show>
      }
      title={view().machine || scope()?.host || "vjproj"}
      subtitle={summary(scope()?.agents)}
      actions={
        <Show when={open() > 0}>
          <IconButton icon={GLYPHS.shell} label="Agents" badge={open()} onClick={() => goto("deck")} />
        </Show>
      }
      fab={
        <Show when={reachable()}>
          <Fab icon={GLYPHS.add} onClick={() => goto("make")}>
            New project
          </Fab>
        </Show>
      }
    >
      <Show when={reachable()} fallback={<Empty icon={GLYPHS.offline} title="Cannot reach the machine." />}>
        <Show when={!bare()} fallback={<Empty icon={GLYPHS.folder} title="No projects yet." />}>
          <Show when={live().length > 0}>
            <Section title="Projects">
              <div class="groups">
                <For each={live()}>
                  {(entry) => (
                    <ProjectGroup
                      place={entry.place}
                      agents={entry.agents}
                      label={labelIn(scope(), entry.project)}
                      home={home()}
                      active={scope()?.active === entry.project}
                      onOpen={() => goto("project", { project: entry.project })}
                      onStart={() => askStart(entry.project)}
                      onOpenAgent={(agent) => goto("pane", { pane: agent.pane, pid: agent.pid })}
                    />
                  )}
                </For>
              </div>
            </Section>
          </Show>

          <Show when={shelf().length > 0}>
            <Section title="Shelf">
              <ListGroup>
                <For each={shelf()}>{(profile) => <ShelfRow profile={profile} home={home()} onOpen={() => adopt(profile)} />}</For>
              </ListGroup>
            </Section>
          </Show>

          <Show when={others().length > 0}>
            <Section title="Machines">
              <ListGroup>
                <For each={others()}>
                  {(peer) => <MachineRow peer={peer} onOpen={() => goto("projects", { machine: peer.host })} />}
                </For>
              </ListGroup>
            </Section>
          </Show>
        </Show>
      </Show>

      <Show when={!view().machine && NOTIFY[standing()]}>
        <Section title="This phone">
          <ListGroup>
            <NotifyRow standing={standing()} onToggle={ring} />
          </ListGroup>
        </Section>
      </Show>
    </Page>
  )
}
