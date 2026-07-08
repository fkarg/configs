import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type Counts = {
  add: number;
  del: number;
};

type UsageWindow = {
  usedPercent: number;
  resetAt: number;
  windowSeconds?: number;
};

type UsageSnapshot = {
  provider: string;
  family?: string;
  primary?: UsageWindow;
  secondary?: UsageWindow;
};

let baseline: Counts = { add: 0, del: 0 };
let lastContext: ExtensionContext | undefined;
const statePath = join(homedir(), ".pi", "agent", "provider-failover-state.json");
const C_RESET = "\x1b[0m";
const C_DIM = "\x1b[90m";
const C_RL = "\x1b[34m";

function parseNumstat(stdout: string): Counts {
  return stdout
    .trim()
    .split("\n")
    .filter(Boolean)
    .reduce(
      (total, line) => {
        const [add, del] = line.split(/\s+/, 3);
        return {
          add: total.add + (add === "-" ? 0 : Number(add || 0)),
          del: total.del + (del === "-" ? 0 : Number(del || 0)),
        };
      },
      { add: 0, del: 0 },
    );
}

async function gitDiffCounts(pi: ExtensionAPI, ctx: ExtensionContext) {
  const result = await pi.exec("git", ["diff", "--numstat"], { cwd: ctx.cwd }).catch(() => undefined);
  return parseNumstat(result?.stdout ?? "");
}

function coloredLineDelta(add: number, del: number) {
  return `\x1b[32m+${add}\x1b[0m/\x1b[31m-${del}\x1b[0m`;
}

function formatTokens(count: number) {
  if (count < 1000) return String(count);
  if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
  if (count < 1000000) return `${Math.round(count / 1000)}k`;
  return `${(count / 1000000).toFixed(1)}M`;
}

function sessionTotals(ctx: ExtensionContext) {
  const totals = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, assistantTurns: 0, messages: 0 };
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message") continue;
    totals.messages++;
    const message = entry.message as any;
    if (message.role !== "assistant") continue;
    totals.assistantTurns++;
    const usage = message.usage;
    if (!usage) continue;
    totals.input += usage.input || 0;
    totals.output += usage.output || 0;
    totals.cacheRead += usage.cacheRead || 0;
    totals.cacheWrite += usage.cacheWrite || 0;
    totals.cost += usage.cost?.total || 0;
  }
  return totals;
}

function sessionStatus(ctx: ExtensionContext) {
  const usage = ctx.getContextUsage();
  const totals = sessionTotals(ctx);
  const parts = [];
  if (usage?.tokens) {
    const percent = usage.percent !== null && usage.percent !== undefined ? ` ${usage.percent.toFixed(1)}%` : "";
    parts.push(`ctx ${formatTokens(usage.tokens)}${percent}`);
  }
  if (totals.assistantTurns) parts.push(`${totals.assistantTurns}t`);
  if (totals.input || totals.output) parts.push(`↑${formatTokens(totals.input)} ↓${formatTokens(totals.output)}`);
  if (totals.cost) parts.push(`$${totals.cost.toFixed(3)}`);
  return parts.length > 0 ? `${C_DIM}${parts.join(" ")}${C_RESET}` : undefined;
}

function usageReport(ctx: ExtensionContext) {
  const totals = sessionTotals(ctx);
  const usage = ctx.getContextUsage();
  const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "unknown";
  return [
    `Model: ${model}`,
    `Context: ${usage?.tokens ? formatTokens(usage.tokens) : "unknown"}${usage?.contextWindow ? ` / ${formatTokens(usage.contextWindow)}` : ""}${usage?.percent !== null && usage?.percent !== undefined ? ` (${usage.percent.toFixed(1)}%)` : ""}`,
    `Turns: ${totals.assistantTurns}`,
    `Messages on branch: ${totals.messages}`,
    `Tokens: ↑${formatTokens(totals.input)} ↓${formatTokens(totals.output)} R${formatTokens(totals.cacheRead)} W${formatTokens(totals.cacheWrite)}`,
    `Cost: $${totals.cost.toFixed(4)}`,
    `Session: ${ctx.sessionManager.getSessionName() || ctx.sessionManager.getSessionId()}`,
  ].join("\n");
}

function formatDuration(seconds: number) {
  const s = Math.max(0, Math.floor(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}h${String(m).padStart(2, "0")}m`;
  if (m > 0) return `${m}m`;
  return `${s}s`;
}

function pace(window: UsageWindow, fallbackWindowSeconds: number, now = Date.now()) {
  const windowSeconds = window.windowSeconds ?? fallbackWindowSeconds;
  const remainingSeconds = Math.max(0, (window.resetAt - now) / 1000);
  const elapsed = Math.min(1, Math.max(0, (windowSeconds - remainingSeconds) / windowSeconds));
  const deviation = window.usedPercent - elapsed * 100;
  if (deviation <= -10) return { color: "0;200;80", glyph: "▲", deviation };
  if (deviation <= -2) return { color: "120;190;120", glyph: "▲", deviation };
  if (deviation < 2) return { color: "90;150;245", glyph: "▬", deviation };
  if (deviation < 5) return { color: "220;190;60", glyph: "▼", deviation };
  return { color: "240;90;90", glyph: "▼", deviation };
}

function paceDiff(window: UsageWindow, fallbackWindowSeconds: number, now = Date.now()) {
  const windowSeconds = window.windowSeconds ?? fallbackWindowSeconds;
  const remainingSeconds = Math.max(0, (window.resetAt - now) / 1000);
  const elapsed = Math.min(1, Math.max(0, (windowSeconds - remainingSeconds) / windowSeconds));
  const deviation = window.usedPercent - elapsed * 100;
  const hours = (deviation / 100) * windowSeconds / 3600;
  const rounded = Math.round(Math.abs(hours));
  if (rounded < 1) return "";
  return hours >= 0 ? `ahead ${rounded}h` : `${rounded}h available`;
}

function quotaLabel(snapshot: UsageSnapshot, kind: "primary" | "secondary") {
  if (kind === "primary") {
    if (snapshot.family === "cursor") return "auth";
    if (snapshot.family === "ollama") return "cloud";
    return "5h";
  }
  return snapshot.family === "ollama" ? "weekly" : "7d";
}

function quotaSegment(label: string, window: UsageWindow, fallbackWindowSeconds: number, showReset: boolean, showDiff: boolean) {
  const now = Date.now();
  const left = Math.max(0, Math.round(100 - window.usedPercent));
  const p = pace(window, fallbackWindowSeconds, now);
  const text = `${label} ${left}% left`;
  const glyph = `\x1b[38;2;${p.color}m${p.glyph}${C_RESET}`;
  const reset = showReset && window.resetAt > now ? ` ${C_DIM}${formatDuration((window.resetAt - now) / 1000)}${C_RESET}` : "";
  const diff = showDiff ? paceDiff(window, fallbackWindowSeconds, now) : "";
  const diffText = diff ? ` ${C_DIM}${diff}${C_RESET}` : "";
  return `${C_RL}${text}${C_RESET}${glyph}${reset}${diffText}`;
}

async function usageSnapshot(provider?: string): Promise<UsageSnapshot | undefined> {
  if (!provider) return undefined;
  const parsed = JSON.parse(await readFile(statePath, "utf8"));
  const snapshots = parsed?.usageByProvider;
  return snapshots?.[provider];
}

async function quotaStatus(ctx: ExtensionContext) {
  const snapshot = await usageSnapshot(ctx.model?.provider).catch(() => undefined);
  if (!snapshot) return undefined;
  const parts = [];
  if (snapshot.primary) parts.push(quotaSegment(quotaLabel(snapshot, "primary"), snapshot.primary, 5 * 60 * 60, true, false));
  if (snapshot.secondary) parts.push(quotaSegment(quotaLabel(snapshot, "secondary"), snapshot.secondary, 7 * 24 * 60 * 60, false, true));
  return parts.length > 0 ? parts.join(" | ") : undefined;
}

async function refresh(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
) {
  lastContext = ctx;
  const [counts, quota] = await Promise.all([gitDiffCounts(pi, ctx), quotaStatus(ctx)]);
  const loc = {
    add: Math.max(0, counts.add - baseline.add),
    del: Math.max(0, counts.del - baseline.del),
  };
  ctx.ui.setStatus("fkarg-loc", coloredLineDelta(loc.add, loc.del));
  ctx.ui.setStatus("fkarg-session", sessionStatus(ctx));
  ctx.ui.setStatus("fkarg-quota", quota);
}

async function reset(pi: ExtensionAPI, ctx: ExtensionContext) {
  baseline = await gitDiffCounts(pi, ctx);
  await refresh(pi, ctx);
}

export default async function (pi: ExtensionAPI) {
  let refreshTimer: NodeJS.Timeout | undefined;

  pi.registerCommand("usage", {
    description: "Show current session/model token and cost usage",
    handler: async (_args, ctx) => {
      await refresh(pi, ctx);
      ctx.ui.notify(usageReport(ctx), "info");
    },
  });

  pi.registerCommand("statusline-reset", {
    description: "Reset the statusline LOC baseline",
    handler: async (_args, ctx) => {
      await reset(pi, ctx);
      ctx.ui.notify("Statusline LOC baseline reset", "info");
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    if (refreshTimer) clearInterval(refreshTimer);
    await reset(pi, ctx);
    refreshTimer = setInterval(() => {
      if (lastContext) void refresh(pi, lastContext);
    }, 5_000);
  });

  pi.on("turn_start", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("turn_end", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("tool_execution_end", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("model_select", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("thinking_level_select", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("message_end", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("session_info_changed", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("session_compact", async (_event, ctx) => {
    await refresh(pi, ctx);
    setTimeout(() => void refresh(pi, ctx), 250);
    setTimeout(() => void refresh(pi, ctx), 1000);
  });

  pi.on("session_tree", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("context", async (_event, ctx) => {
    await refresh(pi, ctx);
  });

  pi.on("session_shutdown", async () => {
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = undefined;
    lastContext?.ui.setStatus("fkarg-loc", undefined);
    lastContext?.ui.setStatus("fkarg-session", undefined);
    lastContext?.ui.setStatus("fkarg-quota", undefined);
    lastContext = undefined;
  });
}
