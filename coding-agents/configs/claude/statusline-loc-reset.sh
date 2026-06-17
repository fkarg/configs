#!/usr/bin/env bash
# Claude Code SessionStart(clear) hook — reset the statusline LOC counter.
#
# The status line shows lines added/removed since the last reset point, computed
# as `current cost counters - a per-session baseline` (see statusline-command.sh).
# `/clear` should make that read 0 again. Claude Code's `cost.total_lines_*`
# counters are cumulative and their behavior across /clear (whether session_id
# changes, whether cost zeroes) is unspecified — so rather than depend on it, we
# simply DELETE the baseline file here. The status line lazily re-baselines to
# whatever the counters read on its next render, which is correct in every case.
#
# Registered for SessionStart matcher `clear` only — NOT `compact`, since
# compaction continues the same working session and the count should carry on.
#
# Fail-open: any error yields a clean exit so a broken hook never blocks /clear.
input="$(cat)"

sid="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)" || exit 0
[ -n "$sid" ] || exit 0

dir="$HOME/.claude/statusline-loc"
rm -f "$dir/$sid" 2>/dev/null

# Prune baselines for sessions that are long gone (files are tiny; this is hygiene).
find "$dir" -type f -mtime +7 -delete 2>/dev/null || true

exit 0
