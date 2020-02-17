#!/bin/sh
# ./home/bez/Coding/.dotfiles/xorg_correct
# ./Coding/.dotfiles/xorg_correct
# ./xorg_correct
xset m 10/1 1
dolphin4 /media/ced/HDD/ &
dolphin4 /media/ced/HDD3/ &
feh --no-xinerama --bg-scale /datadisk/Backup/sdd/ced/Pictures/Space/IMAG7672.JPG

xset -dpms
xset s off

cinnamon-sound-applet &
nm-applet &
redshift -l 48.455467:11.329369 &
xcompmgr &
