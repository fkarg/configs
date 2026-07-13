#!/usr/bin/env bash
# Claude Code PostToolUse hook — inject a diff when the project AGENTS.md
# changes on disk mid-session.
#
# Companion to agents-md-hook.sh, which injects AGENTS.md at session start and
# stashes a snapshot under ~/.cache/claude-agents-md/<session_id>/. After each
# tool call this compares the snapshot against disk (a cmp of a small file —
# cheap next to the hook's own process spawn); on change it emits the unified
# diff as additionalContext — mirroring the native "CLAUDE.md was modified"
# behavior — then advances the snapshot so later changes diff incrementally.
#
# Registered as: hooks.PostToolUse, no matcher (every tool call). Deliberately
# NOT a FileChanged hook: as of Claude Code 2.1.202 that event runs its hooks
# but drops their additionalContext, which would advance the snapshot while
# silently eating the note.
#
# Fail-open: any error (no jq, missing snapshot, ...) yields no output and a
# clean exit, so a broken hook never disrupts a session.

payload="$(cat)"
session="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)" || exit 0
[ -n "$session" ] || exit 0

state="$HOME/.cache/claude-agents-md/$session"
# No snapshot => the session-start hook never injected AGENTS.md for this
# session (CLAUDE.md present, or no AGENTS.md at the root) => nothing to do.
[ -f "$state/snapshot.md" ] && [ -f "$state/path" ] || exit 0
file="$(cat "$state/path")"
[ -f "$file" ] || exit 0 # deleted/renamed — stay silent
cmp -s "$state/snapshot.md" "$file" && exit 0

diff="$(diff -u --label 'AGENTS.md (as loaded)' --label 'AGENTS.md (current)' \
  "$state/snapshot.md" "$file" 2>/dev/null)"
[ -n "$diff" ] || exit 0

cp -f "$file" "$state/snapshot.md" 2>/dev/null

printf '%s' "$diff" | jq -Rs \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: ("Note: the project AGENTS.md was modified during this session (by the user, another session, or this one). This change is intentional; where the diff below conflicts with the previously loaded copy, the diff wins:\n\n" + .)}}' \
  2>/dev/null || true
