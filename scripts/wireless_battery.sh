#! /bin/sh

# # upower --dump | rg percentage | grep -Eo '[0-9]+%$' | tr '\n' ' ' | awk '{print \"M: \"$1\" K: \"$2\" O: \"$3}'
# # for laptop: (first two are battery for some reason)
BAT="$(upower --dump | rg percentage | grep -Eo '[0-9]+%' | tr '\n' ' ' | awk '{print "M: "$1" K: "$2" O: "$3}')"

echo "$BAT"
