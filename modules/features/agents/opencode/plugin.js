const VJPROJ = "@vjproj@"

const report = ($, activity) =>
  $`${VJPROJ} agent report --activity ${activity}`.nothrow().quiet()

export const Vjproj = async ({ $ }) => ({
  "tool.execute.before": async () => {
    await report($, "working")
  },
  "tool.execute.after": async () => {
    await report($, "working")
  },
  event: async ({ event }) => {
    switch (event.type) {
      case "permission.asked":
        await report($, "blocked")
        break
      case "permission.replied":
        await report($, "working")
        break
      case "session.idle":
        await report($, "idle")
        break
      case "session.error":
        await report($, "blocked")
        break
      case "session.deleted":
        await $`${VJPROJ} agent end`.nothrow().quiet()
        break
    }
  },
})
