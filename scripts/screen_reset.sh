#!/bin/sh

# first, activate the internal screen
xrandr --output eDP-1 --auto
sleep 2
# deactivate the misconfigured (?) output
xrandr --output DP-1 --off

sleep 1

echo $(xrandr)

read -p "> Continue? [Enter]"

# reconfigure the external output and deactivate the internal
xrandr --output DP-1 --auto --output eDP-1 --off
