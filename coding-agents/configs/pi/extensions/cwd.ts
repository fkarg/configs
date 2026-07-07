import { resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { createBashToolDefinition } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

function shorten(home: string, cwd: string) {
  if (cwd === home) return "~";
  if (cwd.startsWith(`${home}/`)) return `~/${cwd.slice(home.length + 1)}`;
  return cwd;
}

function resolveCwd(base: string, input: string) {
  if (!input.trim() || input.trim() === ".") return base;
  if (input.trim() === "-") return undefined;
  return resolve(base, input.trim());
}

export default function (pi: ExtensionAPI) {
  let sessionRoot = process.cwd();
  let effectiveCwd = process.cwd();
  let previousCwd: string | undefined;
  let lastContext: ExtensionContext | undefined;

  const refreshStatus = (ctx = lastContext) => {
    if (!ctx) return;
    const display = shorten(process.env.HOME || "", effectiveCwd);
    const root = shorten(process.env.HOME || "", sessionRoot);
    ctx.ui.setStatus("fkarg-cwd", effectiveCwd === sessionRoot ? undefined : `cwd ${display}`);
    return { display, root };
  };

  const bash = createBashToolDefinition(process.cwd(), {
    spawnHook(context) {
      return { ...context, cwd: effectiveCwd };
    },
  });

  pi.registerTool({
    name: "cwd",
    label: "Cwd",
    description: "Show or set the effective working directory for future bash tool calls. Use before working in a git worktree so bash runs in .worktrees/<name> instead of the parent checkout.",
    parameters: Type.Object({
      path: Type.Optional(Type.String({ description: "Directory to switch bash execution to, relative to the current effective cwd. Omit to only report current cwd. Use '-' to switch to the previous cwd." })),
      reset: Type.Optional(Type.Boolean({ description: "Reset bash execution cwd to the original Pi session root.", default: false })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      lastContext = ctx;
      let changed = false;
      if (params.reset) {
        previousCwd = effectiveCwd;
        effectiveCwd = sessionRoot;
        changed = true;
      } else if (params.path?.trim()) {
        const next = params.path.trim() === "-" ? previousCwd : resolveCwd(effectiveCwd, params.path);
        if (!next) {
          return {
            content: [{ type: "text", text: "No previous cwd is available." }],
            details: { sessionRoot, effectiveCwd, previousCwd },
            isError: true,
          };
        }
        const stat = await pi.exec("test", ["-d", next], { cwd: sessionRoot });
        if (stat.code !== 0) {
          return {
            content: [{ type: "text", text: `Not a directory: ${next}` }],
            details: { sessionRoot, effectiveCwd, requested: next },
            isError: true,
          };
        }
        previousCwd = effectiveCwd;
        effectiveCwd = next;
        changed = true;
      }

      const status = refreshStatus(ctx)!;
      const text = [
        `${changed ? "Changed" : "Current"} bash working directory: ${effectiveCwd}`,
        `Session root: ${sessionRoot}`,
        previousCwd ? `Previous cwd: ${previousCwd}` : undefined,
        `Display: ${status.display}`,
      ].filter(Boolean).join("\n");
      return { content: [{ type: "text", text }], details: { sessionRoot, effectiveCwd, previousCwd, changed } };
    },
    renderCall(args, theme) {
      const target = args.reset ? "reset" : args.path || "show";
      return new Text(`${theme.fg("toolTitle", theme.bold("cwd "))}${theme.fg("accent", target)}`, 0, 0);
    },
  });

  pi.registerTool({
    name: "bash",
    label: bash.label,
    description: `${bash.description} The result begins with the working directory where the command executed. Use the cwd tool to change the effective bash working directory, especially before working in .worktrees/<name>.`,
    parameters: bash.parameters,
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      lastContext = ctx;
      const cwdAtExecution = effectiveCwd;
      const result = await bash.execute(toolCallId, params, signal, onUpdate, ctx);
      const first = result.content[0];
      if (first?.type === "text") {
        return {
          ...result,
          content: [{ ...first, text: `Working directory: ${cwdAtExecution}\n\n${first.text}` }, ...result.content.slice(1)],
          details: { ...(result.details || {}), cwd: cwdAtExecution },
        };
      }
      return { ...result, details: { ...(result.details || {}), cwd: cwdAtExecution } };
    },
    renderCall(args, theme) {
      const rawCommand = args.command || "...";
      const cmd = rawCommand.length > 90 ? `${rawCommand.slice(0, 87)}...` : rawCommand;
      const displayCwd = shorten(process.env.HOME || "", effectiveCwd);
      return new Text(`${theme.fg("toolTitle", theme.bold("$ "))}${theme.fg("accent", cmd)}\n${theme.fg("dim", `cwd ${displayCwd}`)}`, 0, 0);
    },
    renderResult: bash.renderResult,
  });

  pi.on("session_start", async (_event, ctx) => {
    sessionRoot = ctx.cwd;
    effectiveCwd = ctx.cwd;
    previousCwd = undefined;
    lastContext = ctx;
    refreshStatus(ctx);
  });

  pi.on("before_agent_start", async (event) => ({
    systemPrompt: `${event.systemPrompt}\n\nBash cwd note: bash tool results include the exact working directory used. Use the cwd tool to inspect or set the effective bash cwd; if set, bash runs there even when the session root is elsewhere. For .worktrees/<name> workflows, call cwd with that path before running repo-local bash commands.`,
  }));

  pi.on("session_shutdown", async () => {
    lastContext?.ui.setStatus("fkarg-cwd", undefined);
    lastContext = undefined;
  });
}
