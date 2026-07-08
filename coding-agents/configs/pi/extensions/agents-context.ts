import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type LoadedContext = { label: string; path: string; content: string };

function readIfExists(path: string): string | undefined {
  try {
    if (!existsSync(path)) return undefined;
    return readFileSync(path, "utf8");
  } catch {
    return undefined;
  }
}

async function gitRoot(pi: ExtensionAPI, cwd: string): Promise<string> {
  const result = await pi.exec("git", ["rev-parse", "--show-toplevel"], { cwd }).catch(() => undefined);
  return result?.code === 0 && result.stdout.trim() ? result.stdout.trim() : cwd;
}

function firstExisting(candidates: Array<{ label: string; path: string }>): LoadedContext | undefined {
  for (const candidate of candidates) {
    const content = readIfExists(candidate.path);
    if (content?.trim()) return { ...candidate, content };
  }
  return undefined;
}

async function loadContexts(pi: ExtensionAPI, ctx: ExtensionContext): Promise<LoadedContext[]> {
  const root = await gitRoot(pi, ctx.cwd);
  const home = homedir();
  const contexts: LoadedContext[] = [];

  const global = firstExisting([
    { label: "Global CLAUDE.md", path: join(home, ".claude", "CLAUDE.md") },
    { label: "Global AGENTS.md", path: join(home, ".codex", "AGENTS.md") },
    { label: "Global AGENTS.md", path: join(home, ".config", "opencode", "AGENTS.md") },
    { label: "Global AGENTS.md", path: join(home, ".pi", "agent", "AGENTS.md") },
  ]);
  if (global) contexts.push(global);

  const project = firstExisting([
    { label: "Project CLAUDE.md", path: join(root, "CLAUDE.md") },
    { label: "Project CLAUDE.md", path: join(root, ".claude", "CLAUDE.md") },
    { label: "Project AGENTS.md", path: join(root, "AGENTS.md") },
  ]);
  if (project) contexts.push(project);

  return contexts;
}

function renderContexts(contexts: LoadedContext[], reason: string) {
  if (contexts.length === 0) return "";
  const header = reason === "compact"
    ? "Re-injected instruction files after compaction. Treat these verbatim files as authoritative over any paraphrased summary."
    : "Instruction files loaded at conversation start. Treat these as authoritative operating instructions.";
  return [
    "",
    "# Auto-loaded instruction files",
    header,
    ...contexts.map((c) => `\n## ${c.label}: ${c.path}\n\n${c.content.trim()}\n`),
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
  let cached = "";
  let lastReason = "startup";
  let lastContext: ExtensionContext | undefined;

  async function reload(ctx: ExtensionContext, reason: string) {
    lastContext = ctx;
    lastReason = reason;
    cached = renderContexts(await loadContexts(pi, ctx), reason);
    ctx.ui.setStatus("agents-context", cached ? "AGENTS" : undefined);
  }

  pi.on("session_start", async (event, ctx) => {
    await reload(ctx, event.reason === "reload" ? "startup" : event.reason);
  });

  pi.on("session_compact", async (_event, ctx) => {
    await reload(ctx, "compact");
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (!cached) await reload(ctx, lastReason);
    if (!cached) return;
    return { systemPrompt: `${event.systemPrompt}\n${cached}` };
  });

  pi.on("session_shutdown", async () => {
    lastContext?.ui.setStatus("agents-context", undefined);
    lastContext = undefined;
  });
}
