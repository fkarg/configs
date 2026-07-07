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
  ctx.ui.setStatus("fkarg-quota", quota);
}

async function reset(pi: ExtensionAPI, ctx: ExtensionContext) {
  baseline = await gitDiffCounts(pi, ctx);
  await refresh(pi, ctx);
}

export default async function (pi: ExtensionAPI) {
  pi.registerCommand("statusline-reset", {
    description: "Reset the statusline LOC baseline",
    handler: async (_args, ctx) => {
      await reset(pi, ctx);
      ctx.ui.notify("Statusline LOC baseline reset", "info");
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    await reset(pi, ctx);
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

  pi.on("session_shutdown", async () => {
    lastContext?.ui.setStatus("fkarg-loc", undefined);
    lastContext?.ui.setStatus("fkarg-quota", undefined);
    lastContext = undefined;
  });
}
