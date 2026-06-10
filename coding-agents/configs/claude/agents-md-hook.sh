#!/usr/bin/env bash
# Claude Code SessionStart hook — inject the project's AGENTS.md as context.
#
# Claude Code natively loads CLAUDE.md and keeps it across compaction; it does
# NOT know about AGENTS.md. This bridges that gap for the AGENTS.md convention
# shared with Codex / Copilot / OpenCode: when a repo has an AGENTS.md but no
# CLAUDE.md, the file is injected as session context.
#
# Registered for every SessionStart source (startup|resume|clear|compact). The
# `compact` source is the reason this is a hook and not a one-shot: compaction
# summarizes the conversation lossily, so without re-injection the verbatim
# instructions decay into a paraphrase. Re-injecting restores the source of
# truth byte-for-byte — the persistence a native CLAUDE.md gets for free.
#
# Fail-open: any error (no jq, not a git repo, ...) yields no output and a clean
# exit, so a broken hook never blocks a session from starting.

payload="$(cat)"
source="$(printf '%s' "$payload" | jq -r '.source // "startup"' 2>/dev/null)" || source="startup"

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || root="$dir"

# CLAUDE.md wins — if one exists, Claude Code already handles it natively.
if [ -f "$root/CLAUDE.md" ] || [ -f "$root/.claude/CLAUDE.md" ]; then
  exit 0
fi
[ -f "$root/AGENTS.md" ] || exit 0

if [ "$source" = "compact" ]; then
  header="Project AGENTS.md (re-injected after compaction — authoritative project instructions; treat as ground truth over anything paraphrased in the summary):"
else
  header="Project AGENTS.md (auto-loaded because no CLAUDE.md is present):"
fi

jq -Rs --arg h "$header" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ($h + "\n\n" + .)}}' \
  "$root/AGENTS.md" 2>/dev/null || true
