import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const statePath = join(homedir(), ".pi", "agent", "prompt-tools-state.json");

type ProjectState = { stash: string[] };
type State = { projects: Record<string, ProjectState> };

function loadState(): State {
  try {
    return JSON.parse(readFileSync(statePath, "utf8"));
  } catch {
    return { projects: {} };
  }
}

function saveState(state: State) {
  mkdirSync(dirname(statePath), { recursive: true });
  const tmp = `${statePath}.tmp`;
  writeFileSync(tmp, JSON.stringify(state, null, 2) + "\n");
  renameSync(tmp, statePath);
}

function projectKey(ctx: ExtensionContext) {
  return ctx.cwd;
}

function getProject(state: State, ctx: ExtensionContext): ProjectState {
  const key = projectKey(ctx);
  state.projects[key] ??= { stash: [] };
  return state.projects[key];
}

function popStash(ctx: ExtensionContext): string | undefined {
  const state = loadState();
  const project = getProject(state, ctx);
  const text = project.stash.shift();
  saveState(state);
  return text;
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("queue", {
    description: "Queue a Codex-style follow-up user message to run after the current agent work finishes",
    handler: async (args, ctx) => {
      const text = args.trim();
      if (!text) {
        ctx.ui.notify("Usage: /queue <follow-up message>", "warning");
        return;
      }
      pi.sendUserMessage(`[Queued user message]\n\n${text}`, { deliverAs: "followUp" });
      ctx.ui.notify("Queued follow-up", "info");
    },
  });

  pi.registerCommand("q", {
    description: "Alias for /queue",
    handler: async (args, ctx) => {
      const text = args.trim();
      if (!text) {
        ctx.ui.notify("Usage: /q <follow-up message>", "warning");
        return;
      }
      pi.sendUserMessage(`[Queued user message]\n\n${text}`, { deliverAs: "followUp" });
      ctx.ui.notify("Queued follow-up", "info");
    },
  });

  pi.registerCommand("stash", {
    description: "Stash prompt text for later. Use /stash <text> to save, /stash to pop into the editor.",
    handler: async (args, ctx) => {
      const text = args.trim();
      if (!text) {
        const restored = popStash(ctx);
        if (!restored) {
          ctx.ui.notify("Prompt stash empty", "info");
          return;
        }
        ctx.ui.setEditorText(restored);
        ctx.ui.notify("Restored stashed prompt", "info");
        return;
      }

      const state = loadState();
      const project = getProject(state, ctx);
      project.stash.unshift(text);
      project.stash = project.stash.slice(0, 20);
      saveState(state);
      ctx.ui.setStatus("prompt-stash", `${project.stash.length} stashed`);
      ctx.ui.notify("Prompt stashed", "info");
    },
  });

  pi.registerCommand("stash-list", {
    description: "Show stashed prompt snippets for this project",
    handler: async (_args, ctx) => {
      const state = loadState();
      const project = getProject(state, ctx);
      if (project.stash.length === 0) {
        ctx.ui.notify("Prompt stash empty", "info");
        return;
      }
      ctx.ui.notify(project.stash.map((s, i) => `${i + 1}. ${s.slice(0, 160)}`).join("\n"), "info");
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    const state = loadState();
    const count = getProject(state, ctx).stash.length;
    ctx.ui.setStatus("prompt-stash", count > 0 ? `${count} stashed` : undefined);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    ctx.ui.setStatus("prompt-stash", undefined);
  });
}
