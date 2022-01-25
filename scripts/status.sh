#! /bin/sh

# STATUS="$(timeout 1 curl -sSf http://club.entropia.de/ | rg '(geschlossen|offen)')"
STATUS="$(timeout 2 curl -sSf https://club.entropia.de/status.json | jq -r '.club_offen')"


if [ -n "$STATUS" ]
then
    echo "$STATUS"
else
    echo unre
fi


