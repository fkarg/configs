#! /bin/bash

# Script 

# execution should toggle between states: multi-display (external above normal)
# and only normal one.

MONITOR=eDP1
EXTERN1=HDMI2
EXTERN2=DP1

EXTERN=None

CONFIGFILE="/tmp/.screenconfig.conf"
CONFIG=None


# if [ $# -eq 1 ]
# then
#     echo "Changing Config"
#     # exactly one argument passed. Parse it and act accordingly
# else
#     echo "Keeping Config"
#     # just check. Output nothing if nothing changed
# fi




function detectExtern {
    if [ -n "$(xrandr -q | rg \^$EXTERN2 | rg \ connected)" ]
    then
        EXTERN=$EXTERN2
    elif [ -n "$(xrandr -q | rg \^$EXTERN1 | rg \ connected)" ]
    then
        EXTERN=$EXTERN1
    else
        EXTERN=None
    fi
}

function getOldConfig {
    if [ -w $CONFIGFILE ]
    then
        CONFIG="$(cat $CONFIGFILE)"
    else
        CONFIG=None
    fi
}


function setNewState {
    if [ "$CONFIG" == "None" ] && [ "$EXTERN" != "None" ]
    then
        xrandr --output $EXTERN --auto --above $MONITOR
    elif [ "$CONFIG" != "None" ] && [ "$EXTERN" == "None" ]
    then
        xrandr --output "$CONFIG" --off
    fi
}

function saveNewConfig {
    echo $EXTERN > $CONFIGFILE
}



detectExtern

echo $EXTERN

getOldConfig

setNewState

saveNewConfig

exit




# setting up new mode for my VGA
# xrandr --newmode "1920x1080" 148.5 1920 2008 2052 2200 1080 1089 1095 1125 +hsync +vsync
# xrandr --addmode VGA1 1920x1080

# default monitor is eDP1

# functions to switch from LVDS1 to VGA and vice versa
function ActivateExtern {
    echo "Activating External"
    xrandr --output VGA1 --mode 1920x1080 --dpi 160 --output LVDS1 --off
    EXTERN=
}
function DeactivateExtern {
    echo "Deactivating External"
    xrandr --output VGA1 --off --output LVDS1 --auto
    EXTERN=
}

# functions to check if VGA is connected and in use
function VGAActive {
    [ $MONITOR = "VGA1" ]
}

function VGAConnected {
    ! xrandr | grep "^VGA1" | grep disconnected
}

# actual script
while true
do
    if ! VGAActive && VGAConnected
    then
        ActivateVGA
    fi

    if VGAActive && ! VGAConnected
    then
        DeactivateVGA
    fi

    sleep 1s
done

