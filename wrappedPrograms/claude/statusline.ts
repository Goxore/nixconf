import { basename } from "node:path"

const fg = "\x1b[39m"
const grey = "\x1b[90m"
const muted = "\x1b[37m"
const red = "\x1b[31m"
const green = "\x1b[32m"
const yellow = "\x1b[33m"
const cyan = "\x1b[36m"
const magenta = "\x1b[35m"
const reset = "\x1b[0m"

const ICONS = {
  model: "\u{F06A9}",
  folder: "\u{F07B}",
  branch: "\u{E0A0}",
  context: "\u{F1C0}",
  rate: "\u{F017}",
  separator: "\u{E0B1}",
} as const

const SEPARATOR = ` ${grey}${ICONS.separator}${reset} `

const USAGE_SCALE = [
  { upTo: 25, color: green },
  { upTo: 66, color: yellow },
  { upTo: Number.POSITIVE_INFINITY, color: red },
] as const

const TOKEN_UNITS = [
  { min: 1_000_000, suffix: "M" },
  { min: 1_000, suffix: "k" },
] as const

const USAGE_TOKEN_FIELDS = [
  "input_tokens",
  "cache_read_input_tokens",
  "cache_creation_input_tokens",
  "output_tokens",
] as const

type TokenUsage = Partial<Record<(typeof USAGE_TOKEN_FIELDS)[number], number>>

type StatusInput = {
  model?: { display_name?: string }
  workspace?: { current_dir?: string }
  cwd?: string
  context_window?: {
    context_window_size?: number
    used_percentage?: number
    current_usage?: TokenUsage
  }
  rate_limits?: {
    five_hour?: { used_percentage?: number; resets_at?: number | string }
    seven_day?: { used_percentage?: number }
  }
}

type Block = (data: StatusInput) => string | null

const segment = (icon: string, color: string, body: string): string =>
  `${color}${icon}${reset} ${body}`

const usageColor = (percentage: number): string =>
  USAGE_SCALE.find(({ upTo }) => percentage <= upTo)!.color

const formatPercentage = (percentage: number): string =>
  `${usageColor(percentage)}${percentage.toFixed(0)}%${reset}`

const formatTokens = (count: number): string => {
  const unit = TOKEN_UNITS.find(({ min }) => count >= min)

  return unit ? `${(count / unit.min).toFixed(1)}${unit.suffix}` : String(count)
}

const formatClock = (timestamp: number | string | undefined): string | null => {
  if (timestamp === undefined || timestamp === null || timestamp === "") return null

  const at = typeof timestamp === "number"
    ? new Date(timestamp * 1000)
    : new Date(String(timestamp))

  if (Number.isNaN(at.getTime())) return null

  const pad = (value: number): string => String(value).padStart(2, "0")

  return `${pad(at.getHours())}:${pad(at.getMinutes())}`
}

const totalTokens = (usage: TokenUsage): number =>
  USAGE_TOKEN_FIELDS.reduce((sum, field) => sum + (usage[field] ?? 0), 0)

const workspaceDir = (data: StatusInput): string =>
  data.workspace?.current_dir || data.cwd || process.cwd()

const gitBranch = (cwd: string): string | null => {
  try {
    const git = Bun.spawnSync(
      ["git", "-C", cwd, "--no-optional-locks", "symbolic-ref", "--short", "HEAD"],
      { stdout: "pipe", stderr: "pipe", timeout: 3000 },
    )

    return git.exitCode === 0 ? git.stdout.toString().trim() || null : null
  } catch {
    return null
  }
}

const blockModel: Block = (data) => {
  const name = (data.model?.display_name ?? "").replace(/\s*\(.*?\)/g, "").trim()

  return name ? segment(ICONS.model, cyan, `${fg}${name}${reset}`) : null
}

const blockFolder: Block = (data) => {
  const cwd = workspaceDir(data)

  return segment(ICONS.folder, yellow, basename(cwd.replace(/[/\\]+$/, "")) || cwd)
}

const blockBranch: Block = (data) => {
  const branch = gitBranch(workspaceDir(data))

  return branch ? segment(ICONS.branch, green, branch) : null
}

const blockContext: Block = (data) => {
  const { context_window_size: size = 0, used_percentage: percentage, current_usage = {} } =
    data.context_window ?? {}
  const used = totalTokens(current_usage)

  if (size > 0) {
    const share = percentage === undefined ? "" : ` ${formatPercentage(percentage)}`

    return segment(ICONS.context, magenta, `${formatTokens(used)}${muted}/${reset}${formatTokens(size)}${share}`)
  }

  return used > 0 ? segment(ICONS.context, magenta, formatTokens(used)) : null
}

const blockRateLimits: Block = (data) => {
  const { five_hour = {}, seven_day = {} } = data.rate_limits ?? {}
  const resetAt = formatClock(five_hour.resets_at)

  const parts = [
    five_hour.used_percentage === undefined
      ? null
      : `${muted}5h${reset} ${formatPercentage(five_hour.used_percentage)}${resetAt ? ` ${grey}@${resetAt}${reset}` : ""}`,
    seven_day.used_percentage === undefined
      ? null
      : `${muted}7d${reset} ${formatPercentage(seven_day.used_percentage)}`,
  ].filter((part): part is string => part !== null)

  return parts.length > 0 ? segment(ICONS.rate, red, parts.join(" ")) : null
}

const BLOCKS: readonly Block[] = [
  blockModel,
  blockFolder,
  blockBranch,
  blockContext,
  blockRateLimits,
]

const render = (data: StatusInput): string =>
  BLOCKS.map((block) => block(data))
    .filter((part): part is string => part !== null)
    .join(SEPARATOR)

const read = async (): Promise<StatusInput | null> => {
  try {
    return JSON.parse(await Bun.stdin.text()) as StatusInput
  } catch {
    return null
  }
}

const data = await read()

console.log(data === null ? `${red}${ICONS.rate} statusline error${reset}` : render(data))
