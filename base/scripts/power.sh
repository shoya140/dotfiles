#!/bin/bash
# Set AC power options given as key=value pairs, such as sleep=0, skipping those this Mac does not support.
# pmset needs sudo, so it runs only for the values that differ.
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: $0 key=value..." >&2; exit 1; }

# Capabilities under any power source heading, so that a laptop running on battery still sets its AC values
capabilities=$(pmset -g cap | awk '/^[ \t]/ { print $1 }')
current=$(pmset -g custom | awk '/^AC Power:/ { ac = 1; next } /^[^ ]/ { ac = 0 } ac { print $1, $2 }')

args=""
for pair in "$@"; do
  key=${pair%%=*}
  value=${pair#*=}
  printf '%s\n' "$capabilities" | grep -qx "$key" || continue
  have=$(printf '%s\n' "$current" | awk -v k="$key" '$1 == k { print $2 }')
  [ "$have" = "$value" ] || args="$args $key $value"
done

[ -n "$args" ] || exit 0
echo "Setting AC power:$args"
sudo pmset -c $args
