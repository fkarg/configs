#!/usr/bin/env python3
"""Patch pi-multi-account quota footer formatting.

The package's built-in `multi-account-quota` status is the accurate/live quota source.
Patch its compact formatter to use the Claude-style pace arrows/colors we prefer, and
avoid wrapping ANSI-rich output in a single theme color.

Like the pi-powerline-footer patch, this runs against the local npm package installed
under ~/.pi/agent/npm; if the package is missing or upstream has changed, it exits
cleanly with a note rather than breaking the Ansible role.
"""
from __future__ import annotations

from pathlib import Path

PACKAGE = Path.home() / ".pi" / "agent" / "npm" / "node_modules" / "pi-multi-account"
USAGE = PACKAGE / "usage.ts"
INDEX = PACKAGE / "index.ts"

OLD_FORMAT = '''export function formatUsageCompact(snapshot: UsageSnapshot, now = Date.now()): string {
	const parts = [providerUsageLabel(snapshot.provider)];
	if (snapshot.primary) {
		const label =
			snapshot.family === "cursor"
				? "auth"
				: snapshot.family === "ollama"
					? "cloud"
					: "5h";
		parts.push(
			`${label} ${remainingPercent(snapshot.primary)}% left/${formatResetDuration(snapshot.primary.resetAt, now)}`,
		);
	}
	if (snapshot.secondary) {
		const weeklyLabel = snapshot.family === "ollama" ? "weekly" : "7d";
		parts.push(
			`${weeklyLabel} ${remainingPercent(snapshot.secondary)}% left/${formatResetDuration(snapshot.secondary.resetAt, now)}`,
		);
	}
	if (!snapshot.primary && !snapshot.secondary && snapshot.plan) {
		if (snapshot.family === "ollama") {
			parts.push(`${snapshot.plan} · no session/weekly API`);
		} else {
			parts.push(snapshot.plan);
		}
	}
	return parts.join(" | ");
}
'''

NEW_FORMAT = '''const ANSI_RESET = "\\x1b[0m";
const ANSI_DIM = "\\x1b[90m";
const ANSI_QUOTA = "\\x1b[34m";

function formatQuotaDuration(seconds: number): string {
	const s = Math.max(0, Math.floor(seconds));
	const h = Math.floor(s / 3600);
	const m = Math.floor((s % 3600) / 60);
	if (h > 0) return `${h}h${String(m).padStart(2, "0")}m`;
	if (m > 0) return `${m}m`;
	return `${s}s`;
}

function quotaPace(window: UsageWindow, fallbackWindowSeconds: number, now = Date.now()) {
	const windowSeconds = window.windowSeconds ?? fallbackWindowSeconds;
	const remainingSeconds = Math.max(0, (window.resetAt - now) / 1000);
	const elapsed = Math.min(1, Math.max(0, (windowSeconds - remainingSeconds) / windowSeconds));
	const deviation = window.usedPercent - elapsed * 100;
	if (deviation <= -10) return { color: "0;200;80", glyph: "▲" };
	if (deviation <= -2) return { color: "120;190;120", glyph: "▲" };
	if (deviation < 2) return { color: "90;150;245", glyph: "▬" };
	if (deviation < 5) return { color: "220;190;60", glyph: "▼" };
	return { color: "240;90;90", glyph: "▼" };
}

function quotaPaceDiff(window: UsageWindow, fallbackWindowSeconds: number, now = Date.now()) {
	const windowSeconds = window.windowSeconds ?? fallbackWindowSeconds;
	const remainingSeconds = Math.max(0, (window.resetAt - now) / 1000);
	const elapsed = Math.min(1, Math.max(0, (windowSeconds - remainingSeconds) / windowSeconds));
	const deviation = window.usedPercent - elapsed * 100;
	const hours = (deviation / 100) * windowSeconds / 3600;
	const rounded = Math.round(Math.abs(hours));
	if (rounded < 1) return "";
	return hours >= 0 ? `ahead ${rounded}h` : `${rounded}h available`;
}

function quotaCompactSegment(label: string, window: UsageWindow, fallbackWindowSeconds: number, showReset: boolean, showDiff: boolean, now = Date.now()) {
	const left = Math.max(0, Math.round(100 - window.usedPercent));
	const pace = quotaPace(window, fallbackWindowSeconds, now);
	const text = `${label} ${left}% left`;
	const glyph = `\\x1b[38;2;${pace.color}m${pace.glyph}${ANSI_RESET}`;
	const reset = showReset && window.resetAt > now ? ` ${ANSI_DIM}${formatQuotaDuration((window.resetAt - now) / 1000)}${ANSI_RESET}` : "";
	const diff = showDiff ? quotaPaceDiff(window, fallbackWindowSeconds, now) : "";
	const diffText = diff ? ` ${ANSI_DIM}${diff}${ANSI_RESET}` : "";
	return `${ANSI_QUOTA}${text}${ANSI_RESET}${glyph}${reset}${diffText}`;
}

export function formatUsageCompact(snapshot: UsageSnapshot, now = Date.now()): string {
	const parts = [providerUsageLabel(snapshot.provider)];
	if (snapshot.primary) {
		const label =
			snapshot.family === "cursor"
				? "auth"
				: snapshot.family === "ollama"
					? "cloud"
					: "5h";
		parts.push(quotaCompactSegment(label, snapshot.primary, 5 * 60 * 60, true, false, now));
	}
	if (snapshot.secondary) {
		const weeklyLabel = snapshot.family === "ollama" ? "weekly" : "7d";
		parts.push(quotaCompactSegment(weeklyLabel, snapshot.secondary, 7 * 24 * 60 * 60, false, true, now));
	}
	if (!snapshot.primary && !snapshot.secondary && snapshot.plan) {
		if (snapshot.family === "ollama") {
			parts.push(`${snapshot.plan} · no session/weekly API`);
		} else {
			parts.push(snapshot.plan);
		}
	}
	return parts.join(" | ");
}
'''

OLD_RENDER = '''			let rendered: string = text;
			try {
				if (ctx.ui.theme?.fg) rendered = ctx.ui.theme.fg(color, text);
			} catch {
				rendered = text;
			}
			ctx.ui.setStatus("multi-account-quota", rendered);
'''

NEW_RENDER = '''			let rendered: string = text;
			try {
				if (!text.includes("\\x1b[") && ctx.ui.theme?.fg) rendered = ctx.ui.theme.fg(color, text);
			} catch {
				rendered = text;
			}
			ctx.ui.setStatus("multi-account-quota", rendered);
'''


def replace_once(path: Path, old: str, new: str) -> str:
    """Return 'changed', 'unchanged', or 'skipped' without ever raising."""
    if not path.exists():
        print(f"skipped: {path} not installed")
        return "skipped"
    text = path.read_text()
    if new in text:
        return "unchanged"
    if old not in text:
        print(f"skipped: expected patch anchor not found in {path}")
        return "skipped"
    path.write_text(text.replace(old, new, 1))
    return "changed"


def main() -> None:
    results = [
        replace_once(USAGE, OLD_FORMAT, NEW_FORMAT),
        replace_once(INDEX, OLD_RENDER, NEW_RENDER),
    ]
    if "changed" in results:
        print("changed: pi-multi-account quota format")
    elif "skipped" in results:
        print("skipped: pi-multi-account quota format")
    else:
        print("unchanged: pi-multi-account quota format")


if __name__ == "__main__":
    main()
