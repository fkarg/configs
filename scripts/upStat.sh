#!/bin/bash

mount /dev/sdb1 /datadisk
feh --no-xinerama --bg-scale /home/pars/Pictures/Space/IMAG7297.JPG

swapoff -a

redshift -l 48.455467:11.329369 &
xcompmgr &

xset -dpms
xset s off

htop
shutdown -P 1

