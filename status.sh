#! /bin/bash

# STATUS="$(timeout 1 curl -sSf http://club.entropia.de/ | rg '(geschlossen|offen)')"
STATUS="$(timeout 1 curl -sSf http://club.entropia.de/status.json | jq -r '.club_offen')"

echo "$STATUS"


