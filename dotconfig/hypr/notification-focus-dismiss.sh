#!/usr/bin/env bash
# Watch Hyprland focus events; dismiss mako notifications whose source
# matches the newly focused window's class.
#
# Matching is case-insensitive and bidirectional substring against both
# `desktop_entry` (preferred) and `app_name` from `makoctl list -j`.
#
# Started via exec-once in hyprland.conf. Logs to /tmp/notification-focus-dismiss.log
# for debugging — comment out if unwanted.

set -u

sig=${HYPRLAND_INSTANCE_SIGNATURE:-}
if [ -z "$sig" ]; then
  echo "HYPRLAND_INSTANCE_SIGNATURE not set" >&2
  exit 1
fi

sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/.socket2.sock"
log=/tmp/notification-focus-dismiss.log

norm() { printf '%s' "${1,,}"; }

dismiss_for_class() {
  local class_l=$1
  [ -z "$class_l" ] && return

  # Pull notifications and select ids matching by app_name or desktop_entry
  # using case-insensitive bidirectional substring.
  local ids
  ids=$(makoctl list -j 2>/dev/null | jq -r --arg c "$class_l" '
    .[]
    | . as $n
    | ($n.app_name // "" | ascii_downcase) as $a
    | ($n.desktop_entry // "" | ascii_downcase) as $d
    | select(
        ($a != "" and ($a == $c or ($a | contains($c)) or ($c | contains($a))))
        or
        ($d != "" and ($d == $c or ($d | contains($c)) or ($c | contains($d))))
      )
    | .id
  ' 2>/dev/null) || return

  for id in $ids; do
    makoctl dismiss -n "$id" 2>/dev/null
    echo "$(date -Iseconds) dismissed id=$id class=$class_l" >> "$log"
  done
}

socat -U - "UNIX-CONNECT:$sock" 2>/dev/null | while IFS= read -r line; do
  case "$line" in
    activewindow\>\>*)
      payload=${line#activewindow>>}
      class=${payload%%,*}
      [ -n "$class" ] && dismiss_for_class "$(norm "$class")"
      ;;
  esac
done
