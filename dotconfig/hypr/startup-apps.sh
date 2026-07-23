#!/usr/bin/env bash
# Jolly's startup window layout, run once from hyprland.conf's exec-once.
# hyprland.conf is shared across hosts, so this exits everywhere but jolly.
# Safe to re-run by hand to restore the layout after closing things.
[ "$(hostname)" = jolly ] || exit 0

# Scratchpad (Super+S): system monitor.
hyprctl dispatch exec '[workspace special:magic silent] kitty -e btop'

# ws3: kitty with one tab per active project (see dotconfig/kitty/dev.session).
hyprctl dispatch exec '[workspace 3 silent] kitty --session ~/.config/kitty/dev.session'

# ws2: firefox default profile (Kolai). ws9: Personal profile; --no-remote lets
# the second instance run alongside and keeps external links opening in Kolai.
hyprctl dispatch exec '[workspace 2 silent] firefox'
hyprctl dispatch exec '[workspace 9 silent] firefox --no-remote -P Personal'

# ws4: music.
hyprctl dispatch exec '[workspace 4 silent] pear-desktop'

# ws1: one VSCode window per project. code is single-instance: only the first
# launch owns a PID Hyprland can apply the workspace rule to; later launches
# hand off to it and their windows open on the focused workspace instead. Right
# after login that focused workspace is 1 anyway, and the sleeps keep the
# handoff windows from racing the first launch.
hyprctl dispatch exec '[workspace 1 silent] code -n ~/Coding/frontend-react'
sleep 4
hyprctl dispatch exec '[workspace 1 silent] code -n ~/Coding/backend-core'
# Occasionally wanted; uncomment when a session needs it.
# sleep 2
# hyprctl dispatch exec '[workspace 1 silent] code -n ~/Coding/infrastructure'
