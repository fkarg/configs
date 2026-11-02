#!/usr/bin/env bash
# Jolly's startup window layout, run once from hyprland.lua's hyprland.start hook.
# hyprland.lua is shared across hosts, so this exits everywhere but jolly.
# Safe to re-run by hand to restore the layout after closing things.
[ "$(hostname)" = jolly ] || exit 0

# With a Lua config, hyprctl's parser is Lua too, so the old
# `hyprctl dispatch exec '[workspace N silent] cmd'` form no longer parses.
# Launch rules move into hl.exec_cmd's rule table; the value is the same rule
# string the brackets used to hold ("3 silent"). Long-bracket Lua strings avoid
# escaping the command's own quotes and `~`.
#
# hyprctl exits 7 on a parse error, so check it: a syntax regression here is
# otherwise completely silent and just leaves an empty desktop.
launch() {
    local ws=$1 cmd=$2
    hyprctl eval "hl.exec_cmd([[$cmd]], {workspace = [[$ws]]})" >/dev/null \
        || echo "startup-apps: launch failed (ws $ws): $cmd" >&2
}

# kitty: bring back every kitty window from the latest hourly kitty-snapshot
# (tabs, cwds, and open Claude/Codex sessions resumed by id), each on the
# workspace it was on. The two standard windows fall back to their static
# sessions when the snapshot has none for their workspace:
#   Scratchpad (Super+S): system monitor (dotconfig/kitty/monitor.session).
#   ws3: one tab per active project (dotconfig/kitty/dev.session).
# Re-running this by hand resumes those agent sessions a second time while the
# originals are still open; close the duplicates.
declare -A kitty_default=(
    [special:magic]=~/.config/kitty/monitor.session
    [3]=~/.config/kitty/dev.session
)
for session in "${XDG_STATE_HOME:-$HOME/.local/state}"/kitty-snapshot/latest/*.kitty-session; do
    [ -e "$session" ] || continue
    ws=${session##*/}
    ws=${ws%%.*}  # "3.kitty-session", "3.2.kitty-session" -> "3"
    launch "$ws silent" "kitty --session $session"
    unset "kitty_default[$ws]"
done
for ws in "${!kitty_default[@]}"; do
    launch "$ws silent" "kitty --session ${kitty_default[$ws]}"
done

# ws2: firefox default profile (Kolai). ws9: Personal profile; --no-remote lets
# the second instance run alongside and keeps external links opening in Kolai.
launch '2 silent' 'firefox'
launch '9 silent' 'firefox --no-remote -P Personal'

# ws4: music.
launch '4 silent' 'pear-desktop'

# ws1: one VSCode window per project. code is single-instance: only the first
# launch owns a PID Hyprland can apply the workspace rule to; later launches
# hand off to it and their windows open on the focused workspace instead. Right
# after login that focused workspace is 1 anyway, and the sleeps keep the
# handoff windows from racing the first launch.
launch '1 silent' 'code -n ~/Coding/frontend-react'
sleep 4
launch '1 silent' 'code -n ~/Coding/backend-core'
# Occasionally wanted; uncomment when a session needs it.
# sleep 2
# launch '1 silent' 'code -n ~/Coding/infrastructure'
