#!/usr/bin/env bash
# Claude Code Stop hook — deferred message queue ("send when otherwise done").
#
# Claude Code's native input queue (typing while it works) is delivered at the
# next *stop opportunity*, which can be an intermediate pause — so it behaves as
# steering. This hook gives the Codex-style semantic instead: a follow-up runs
# ONLY when the turn would otherwise fully terminate.
#
# The `Stop` event fires when the main agent has finished responding and is about
# to hand control back to the user (true termination — not mid-turn tool pauses;
# subagents fire SubagentStop instead). If a line is queued for this project, we
# emit {"decision":"block","reason":...} so Claude continues with that line as its
# next instruction. One line is drained per turn-end, in order.
#
# Enqueue out-of-band from a second terminal/pane with the `cq` fish function
# (bang-mode `!cmd` does NOT execute mid-turn — it only queues as raw text).
#
# Termination is guaranteed by emptiness: every block pops exactly one line, so
# the queue strictly shrinks. (Claude Code also caps consecutive Stop-blocks at
# ~8; a longer queue just drains in batches across turn-ends.)
#
# Queue file is keyed by git root (cwd fallback) so a `cq` run from the same repo
# targets the same session. Key derivation MUST match cq.fish:
#   root -> s#/#%#g  ->  ~/.claude/queue/<key>
#
# Fail-open: any error yields no output and a clean exit, so a broken hook never
# wedges a session.

input="$(cat)"

dir="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)" || dir=""
[ -n "$dir" ] || dir="$PWD"
root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || root="$dir"

key="$(printf '%s' "$root" | sed 's#/#%#g')"
queue="$HOME/.claude/queue/$key"

[ -s "$queue" ] || exit 0

next="$(head -n1 "$queue")"
# Pop the first line regardless of content (guarantees the queue shrinks).
tail -n +2 "$queue" > "$queue.tmp" 2>/dev/null && mv "$queue.tmp" "$queue"
[ -s "$queue" ] || rm -f "$queue"

# Skip blank lines: let Claude stop, drain the rest on the next turn-end.
[ -n "$next" ] || exit 0

# Claude Code delivers `reason` framed as generic "Stop hook feedback", which
# reads like a system/tooling nag. Prepend a preamble so the model treats the
# line as what it is: a follow-up the user deliberately queued, equivalent to a
# new user turn.
preamble="[Queued user message] The user enqueued the request below via \`cq\` while you were working; it is being delivered now because you would otherwise have stopped. Treat it as a new user instruction (not system/tooling feedback) and act on it:"

jq -n --arg p "$preamble" --arg r "$next" \
  '{decision: "block", reason: ($p + "\n\n" + $r)}' 2>/dev/null || true
