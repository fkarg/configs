/** @jsxImportSource @opentui/solid */
import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui"
import { createSignal, Show } from "solid-js"

async function loadCore() {
  return import("../shared/statusline/core.mjs").catch(() => import("../../shared/statusline/core.mjs"))
}

type Usage = {
  input: number
  output: number
}

function currentSessionID(api: Parameters<TuiPlugin>[0]) {
  const route = api.route.current
  if (route.name !== "session") return
  const params = "params" in route ? route.params : undefined
  return typeof params?.sessionID === "string" ? params.sessionID : undefined
}

function numeric(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0
}

function usageFromMessage(message: unknown): Usage {
  if (!message || typeof message !== "object") return { input: 0, output: 0 }
  const record = message as Record<string, unknown>
  const usage = record.usage && typeof record.usage === "object" ? (record.usage as Record<string, unknown>) : {}
  return {
    input: numeric(usage.input) + numeric(usage.inputTokens) + numeric(usage.prompt_tokens),
    output: numeric(usage.output) + numeric(usage.outputTokens) + numeric(usage.completion_tokens),
  }
}

function sessionUsage(api: Parameters<TuiPlugin>[0], sessionID: string): Usage {
  return api.state.session.messages(sessionID).reduce(
    (total, message) => {
      const next = usageFromMessage(message)
      return { input: total.input + next.input, output: total.output + next.output }
    },
    { input: 0, output: 0 },
  )
}

function sessionLines(api: Parameters<TuiPlugin>[0], sessionID: string) {
  return api.state.session.diff(sessionID).reduce(
    (total, file) => ({
      add: total.add + numeric((file as Record<string, unknown>).added) + numeric((file as Record<string, unknown>).additions),
      del:
        total.del +
        numeric((file as Record<string, unknown>).removed) +
        numeric((file as Record<string, unknown>).deleted) +
        numeric((file as Record<string, unknown>).deletions),
    }),
    { add: 0, del: 0 },
  )
}

function modelLabel(api: Parameters<TuiPlugin>[0]) {
  const model = api.state.config.model
  if (typeof model === "string" && model.length > 0) return model
  return "model ?"
}

function stateLabel(api: Parameters<TuiPlugin>[0], sessionID: string) {
  const status = api.state.session.status(sessionID)
  if (!status || typeof status !== "object") return "ready"
  const type = (status as Record<string, unknown>).type
  return typeof type === "string" ? type : "working"
}

function contextLabel(usage: Usage, formatCount: (value: number) => string) {
  const total = usage.input + usage.output
  return total > 0 ? `${formatCount(total)} tok` : ""
}

const tui: TuiPlugin = async (api) => {
  const { buildStatusParts, fitStatusLine, formatCount } = await loadCore()
  const [tick, setTick] = createSignal(0)
  const timer = setInterval(() => setTick((value) => value + 1), 30000)
  api.lifecycle.onDispose(() => clearInterval(timer))

  api.slots.register({
    slots: {
      app_bottom(ctx) {
        tick()
        const sessionID = currentSessionID(api)
        const theme = ctx.theme.current
        const width = Math.max(20, process.stdout.columns || 80)
        const session = sessionID ? api.state.session.get(sessionID) : undefined
        const usage = sessionID ? sessionUsage(api, sessionID) : { input: 0, output: 0 }
        const parts = buildStatusParts({
          cwd: session?.directory ?? api.state.path.directory,
          home: process.env.HOME,
          branch: api.state.vcs?.branch,
          model: modelLabel(api),
          tokens: usage.input || usage.output ? usage : undefined,
          lines: sessionID ? sessionLines(api, sessionID) : undefined,
          context: contextLabel(usage, formatCount),
          state: sessionID ? stateLabel(api, sessionID) : undefined,
          pathWidth: 34,
        })
        const line = fitStatusLine(parts, width)

        return (
          <Show when={api.route.current.name === "session" && line.length > 0}>
            <box width="100%" flexShrink={0} paddingLeft={1} paddingRight={1}>
              <text fg={theme.textMuted}>{line}</text>
            </box>
          </Show>
        )
      },
    },
  })
}

const plugin: TuiPluginModule & { id: string } = {
  id: "fkarg.statusline",
  tui,
}

export default plugin
