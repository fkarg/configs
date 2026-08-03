#!/usr/bin/env bash
# Claude Code SessionEnd hook — push the finished transcript to the sync hub.
#
# The periodic agent-sync timer alone is either too laggy to walk from one
# machine to another, or too chatty if tightened. This closes that gap: the
# moment a session ends, its transcript is on the hub and resumable from the
# other hosts, and the timer stays a low-frequency backstop for crashed
# sessions and Codex rollouts.
#
# Fires on every termination — including `clear` and `resume`, not just exit —
# which is harmless: each firing is one small rsync of a settled file.
#
# DETACHED ON PURPOSE. All SessionEnd hooks share a 1.5s budget by default
# (raisable to at most 60s), and an rsync over SSH to a VPS can exceed that on a
# slow link. Blocking would mean a truncated push and a visibly stalled exit, so
# the transfer is backgrounded and the hook returns immediately; the push
# completes after Claude Code is gone.
#
# nohup rather than setsid: macOS ships no setsid, and this hook has to work
# unchanged on both caeli and jolly.
#
# Fail-open: any error yields a clean exit, so a broken hook never disrupts the
# end of a session.

payload="$(cat)"

transcript="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)" || exit 0
[ -n "$transcript" ] || exit 0
[ -f "$transcript" ] || exit 0

sync_bin="$HOME/.local/bin/agent-sync"
[ -x "$sync_bin" ] || exit 0

nohup "$sync_bin" file "$transcript" </dev/null >/dev/null 2>&1 &

exit 0
