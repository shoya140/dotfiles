#!/bin/bash
# Keep the Mac reachable on AC power: never sleep, wake for network access, and restart after a power
# failure where the hardware supports it. pmset needs sudo, so it runs only for the values that differ.
set -euo pipefail

WANT="sleep=0 womp=1 autorestart=1"

capabilities=$(pmset -g cap | awk '/^Capabilities for AC Power:/ { ac = 1; next } /^[^ ]/ { ac = 0 } ac { print $1 }')
current=$(pmset -g custom | awk '/^AC Power:/ { ac = 1; next } /^[^ ]/ { ac = 0 } ac { print $1, $2 }')

args=""
for pair in $WANT; do
  key=${pair%%=*}
  value=${pair#*=}
  printf '%s\n' "$capabilities" | grep -qx "$key" || continue
  have=$(printf '%s\n' "$current" | awk -v k="$key" '$1 == k { print $2 }')
  [ "$have" = "$value" ] || args="$args $key $value"
done

[ -n "$args" ] || exit 0
echo "Setting AC power:$args"
sudo pmset -c $args
