#!/bin/sh

export EDITOR=nvim

P1=~/.config/broot/launcher/bash/br
P2=~/.local/share/broot/launcher/bash/1
[[ -f "$P1" ]] && source "$P1"
[[ -f "$P2" ]] && source "$P2"

cd ~/text_zeug/$1
br
