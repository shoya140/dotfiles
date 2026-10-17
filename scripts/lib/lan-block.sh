#!/bin/bash
# Keep one user off the local network with a pf anchor: block that user's new TCP connections and UDP packets
# to private, link-local and multicast ranges and to every network this Mac is on, and block network file
# system ports for everyone. A LaunchDaemon loads the anchor at boot and again every five minutes, which also
# turns pf back on. The tailnet is left to the tailnet policy. Run as root: lan-block.sh <user> <name>
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <user> <name>" >&2; exit 1; }
user=$1
name=$2
anchor="com.apple/$name"
rules="/etc/pf.anchors/$name"
label="local.$name.pf"
plist="/Library/LaunchDaemons/$label.plist"

id -u "$user" >/dev/null

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

cat > "$tmp" <<EOF
# Written by lan-block.sh for the user $user. fd7a:115c:a1e0::/48 and 100.64.0.0/10 are the tailnet.
table <lan> const { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 224.0.0.0/4, 255.255.255.255, fc00::/7, !fd7a:115c:a1e0::/48, fe80::/10, ff00::/8 }

# The kernel opens SMB and NFS connections itself, so the user rules below would not see a mount.
block return out quick proto { tcp, udp } from any to <lan> port { 111, 139, 445, 2049 }

pass out quick proto { tcp, udp } from any to { 127.0.0.0/8, ::1, 100.64.0.0/10, fd7a:115c:a1e0::/48 } user $user no state
pass out quick proto { tcp, udp } from any to { <lan>, (self:network) } port 53 user $user
block return out quick proto tcp from any to { <lan>, (self:network) } user $user flags S/SA
block return out quick proto udp from any to { <lan>, (self:network) } user $user
EOF
# pfctl always warns about -f, so its output is shown only when the rules do not parse
if ! out=$(/sbin/pfctl -q -n -f "$tmp" 2>&1); then
  printf '%s\n' "$out" >&2
  exit 1
fi

if ! cmp -s "$tmp" "$rules"; then
  install -m 644 -o root -g wheel "$tmp" "$rules"
  echo "Wrote $rules"
fi

cat > "$tmp" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$label</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/sh</string>
		<string>-c</string>
		<string>/sbin/pfctl -q -a $anchor -f $rules &amp;&amp; { /sbin/pfctl -q -e 2&gt;/dev/null; true; }</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>300</integer>
</dict>
</plist>
EOF
plutil -lint "$tmp" >/dev/null

if ! cmp -s "$tmp" "$plist"; then
  install -m 644 -o root -g wheel "$tmp" "$plist"
  launchctl bootout "system/$label" 2>/dev/null || true
  echo "Wrote $plist"
fi
launchctl print "system/$label" >/dev/null 2>&1 || launchctl bootstrap system "$plist"
launchctl kickstart -k "system/$label"

# pfctl reports the anchor only after launchd has run the job
for _ in 1 2 3 4 5 6 7 8 9 10; do
  loaded=$(/sbin/pfctl -a "$anchor" -s rules 2>/dev/null)
  grep -q "user = $(id -u "$user")" <<<"$loaded" && break
  sleep 1
done
info=$(/sbin/pfctl -s info 2>/dev/null)
grep -q 'Status: Enabled' <<<"$info" || { echo "pf is not enabled" >&2; exit 1; }
grep -q "user = $(id -u "$user")" <<<"$loaded" || { echo "The anchor $anchor is not loaded" >&2; exit 1; }
echo "pf keeps $user off the local network (anchor $anchor)"
