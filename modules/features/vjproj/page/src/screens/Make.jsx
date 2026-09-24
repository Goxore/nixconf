import { For, Show, createSignal, onMount } from "solid-js"
import { Button } from "#ui/Button.jsx"
import { Page, Back } from "#ui/Page.jsx"
import { Section, ListGroup, ListRow } from "#ui/List.jsx"
import { Field } from "#ui/Controls.jsx"
import { Icon } from "#ui/Icon.jsx"
import { GLYPHS } from "#lib/glyphs.js"
import { complain, goto } from "#lib/nav.js"
import { path, pullState, scope } from "#lib/store.js"
import { send } from "#lib/api.js"
import { basename, dirsKnownTo, homeOf, tilde } from "#lib/model.js"

export const Make = () => {
  let field
  const [dir, setDir] = createSignal("")
  const home = () => homeOf(scope())
  const known = () => dirsKnownTo(scope()).map((one) => tilde(home(), one))
  const matching = () => known().filter((one) => one !== dir() && one.includes(dir().trim()))

  onMount(() => field.focus())

  const create = (event) => {
    event.preventDefault()
    if (!dir().trim()) return
    send(path("/project"), { dir: dir().trim() })
      .then(async ({ project }) => {
        await pullState()
        goto("project", { project }, { replace: true })
      })
      .catch(() => complain("Could not create it."))
  }

  return (
    <Page leading={<Back />} title="New project">
      <form class="form" onSubmit={create}>
        <Field ref={field} label="Folder" support="Inside your home folder" value={dir()} enter="go" onInput={setDir} />
        <div class="form-actions">
          <Button type="submit" icon={GLYPHS.add} disabled={!dir().trim()}>
            Create
          </Button>
        </div>
      </form>

      <Show when={matching().length > 0}>
        <Section title="Known folders">
          <ListGroup>
            <For each={matching()}>
              {(one) => (
                <ListRow
                  leading={<Icon name={GLYPHS.folder} />}
                  headline={basename(one)}
                  supporting={one}
                  onClick={() => {
                    setDir(one)
                    field.focus()
                  }}
                />
              )}
            </For>
          </ListGroup>
        </Section>
      </Show>
    </Page>
  )
}
