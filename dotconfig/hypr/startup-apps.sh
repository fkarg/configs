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

# Scratchpad (Super+S): system monitor (see dotconfig/kitty/monitor.session).
launch 'special:magic silent' 'kitty --session ~/.config/kitty/monitor.session'

# ws3: kitty with one tab per active project (see dotconfig/kitty/dev.session).
launch '3 silent' 'kitty --session ~/.config/kitty/dev.session'

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
