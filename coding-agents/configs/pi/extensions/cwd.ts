import { relative, resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { createBashToolDefinition } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

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

  pi.registerCommand("cwd", {
    description: "Show or set the effective working directory for bash tool calls. Use /cwd <path>, /cwd -, or /cwd --reset.",
    handler: async (args, ctx) => {
      lastContext = ctx;
      const arg = args.trim();
      if (!arg) {
        const s = refreshStatus(ctx)!;
        ctx.ui.notify(`bash cwd: ${s.display}\nsession root: ${s.root}`, "info");
        return;
      }
      if (arg === "--reset" || arg === "reset") {
        previousCwd = effectiveCwd;
        effectiveCwd = sessionRoot;
        refreshStatus(ctx);
        ctx.ui.notify(`bash cwd reset: ${shorten(process.env.HOME || "", effectiveCwd)}`, "info");
        return;
      }
      const next = arg === "-" ? previousCwd : resolveCwd(effectiveCwd, arg);
      if (!next) {
        ctx.ui.notify("No previous cwd", "warning");
        return;
      }
      const stat = await pi.exec("test", ["-d", next], { cwd: sessionRoot });
      if (stat.code !== 0) {
        ctx.ui.notify(`Not a directory: ${next}`, "error");
        return;
      }
      previousCwd = effectiveCwd;
      effectiveCwd = next;
      refreshStatus(ctx);
      ctx.ui.notify(`bash cwd: ${shorten(process.env.HOME || "", effectiveCwd)}`, "info");
    },
  });

  pi.registerTool({
    name: "bash",
    label: bash.label,
    description: `${bash.description} The result begins with the working directory where the command executed. The user can change that directory with /cwd.`,
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
    systemPrompt: `${event.systemPrompt}\n\nBash cwd note: bash tool results include the exact working directory used. The user may set an effective bash cwd with /cwd; if set, bash runs there even when the session root is elsewhere.`,
  }));

  pi.on("session_shutdown", async () => {
    lastContext?.ui.setStatus("fkarg-cwd", undefined);
    lastContext = undefined;
  });
}
