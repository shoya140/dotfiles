#!/bin/bash
# Runs on the oMLX host as an administrator. ../setup copies it there and starts it.
set -euo pipefail

OMLX_VERSION=0.7.1rc1
OMLX_DMG_SHA256=a9efb6eada12b5765de26c456342ed6bc2faefbeafae07ab4c7bcf544aaf352e
OMLX_TEAM_ID=PSK5Q5T46L
SERVICE_USER=omlx
PORT=8000
CLIENT_KEY_NAME=openclaw
# Models are chosen in the oMLX admin pages; these aliases mark the ones OpenClaw uses
CHAT_ALIAS=chat
EMBEDDING_ALIAS=embedding

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
APP="/opt/omlx/$OMLX_VERSION/oMLX.app"
LABEL=local.omlx.serve
SERVE_PATHS="/v1/chat/completions /v1/embeddings"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# The service account cannot read this account's home, which sudo -u would otherwise start in
cd /

step() { printf '\n== %s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }
as_service() { sudo -u "$SERVICE_USER" -H "$@"; }
# Write stdin to a file owned by the service account: write_as_service <umask> <file>
write_as_service() { as_service /bin/sh -c 'umask "$1" && cat > "$2.tmp" && mv "$2.tmp" "$2"' sh "$1" "$2"; }

step "Checking this Mac"
[ "$(uname -s)" = Darwin ] || die "This is not macOS."
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ] || die "The pinned oMLX build needs macOS 26 or later."
dseditgroup -o checkmember -m "$USER" admin >/dev/null || die "$USER is not an administrator."
launchctl print system/homebrew.mxcl.tailscale >/dev/null 2>&1 ||
  die "The Tailscale daemon is not running. Move this Mac to the cui role first."
ts=$(tailscale status --json) || die "tailscaled is not running."
# Before 1.98, tailscaled itself dials non-tailnet addresses for `tailscale nc`, which would let any account
# reach the local network as root
version=$(jq -r '.Version | split("-")[0]' <<<"$ts")
[ "$(printf '1.98.0\n%s\n' "$version" | sort -t. -k1,1n -k2,2n -k3,3n | head -n 1)" = 1.98.0 ] ||
  die "tailscaled $version is older than 1.98. Upgrade it: brew upgrade tailscale, then sudo brew services restart tailscale"
[ "$(jq -r .BackendState <<<"$ts")" = Running ] || die "Tailscale is not connected."
jq -e '(.Self.Tags // []) | index("tag:omlx")' <<<"$ts" >/dev/null ||
  die "This Mac does not have the tag tag:omlx. Apply the tailnet policy and the tag first (README.md)."
jq -e '(.CertDomains // []) | length > 0' <<<"$ts" >/dev/null ||
  die "HTTPS certificates are off for the tailnet. Turn them on in the admin console under DNS."
fqdn=$(jq -r '.Self.DNSName | rtrimstr(".")' <<<"$ts")
echo "$fqdn, $(( $(sysctl -n hw.memsize) / 1073741824 )) GB of memory"
sudo -v

step "The $SERVICE_USER account"
if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
  echo "Creating the standard account $SERVICE_USER. Nobody logs in to it, so any password will do."
  sudo sysadminctl -addUser "$SERVICE_USER" -fullName oMLX -password -
fi
# A service account: hidden from the login window and without a login shell
sudo dscl . -create "/Users/$SERVICE_USER" IsHidden 1
sudo dscl . -create "/Users/$SERVICE_USER" UserShell /usr/bin/false
if dseditgroup -o checkmember -m "$SERVICE_USER" admin >/dev/null 2>&1; then
  die "$SERVICE_USER is an administrator; it has to be a standard account."
fi
uid=$(id -u "$SERVICE_USER")
home=$(dscl . -read "/Users/$SERVICE_USER" NFSHomeDirectory | awk '{ print $2 }')
[ -d "$home" ] || sudo createhomedir -c -u "$SERVICE_USER" >/dev/null
base="$home/.omlx"
models="$base/models"
log="$home/Library/Logs/omlx/serve.log"
as_service mkdir -p "$models" "${log%/*}"
as_service touch "$log"
echo "$SERVICE_USER (uid $uid), $home"

step "oMLX $OMLX_VERSION"
if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null)" != "$OMLX_VERSION" ]; then
  curl -fL --retry 3 -o "$work/omlx.dmg" \
    "https://github.com/jundot/omlx/releases/download/v$OMLX_VERSION/oMLX-$OMLX_VERSION-macos26-27.dmg"
  echo "$OMLX_DMG_SHA256  $work/omlx.dmg" | shasum -a 256 -c - >/dev/null
  mkdir "$work/mnt"
  hdiutil attach -quiet -readonly -nobrowse -mountpoint "$work/mnt" "$work/omlx.dmg"
  sudo mkdir -p "${APP%/*}"
  sudo rm -rf "$APP"
  sudo ditto "$work/mnt/oMLX.app" "$APP"
  hdiutil detach -quiet "$work/mnt"
  sudo chown -R root:wheel "$APP"
fi
codesign --verify --deep --strict "$APP"
team=$(codesign -dv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')
[ "$team" = "$OMLX_TEAM_ID" ] || die "$APP is signed by team ${team:-none}, not by the oMLX developer ($OMLX_TEAM_ID)."
echo "$APP"

step "Keeping $SERVICE_USER off the local network"
sudo /bin/bash "$HERE/../lib/lan-block.sh" "$SERVICE_USER" omlx

step "Server settings"
settings="$base/settings.json"
plist_file="/Library/LaunchDaemons/$LABEL.plist"
current=$(as_service cat "$settings" 2>/dev/null || echo '{}')
main_key=$(jq -r '.auth.api_key // empty' <<<"$current")
[ -n "$main_key" ] || main_key="omlx-$(openssl rand -hex 24)"
client_key=$(jq -r --arg n "$CLIENT_KEY_NAME" '[.auth.sub_keys[]? | select(.name == $n)][0].key // empty' <<<"$current")
[ -n "$client_key" ] || client_key="omlx-$(openssl rand -hex 24)"
# Requests through Tailscale Serve arrive from 127.0.0.1, which oMLX treats as local, so the keys must stay
# required: a main key set and both bypass switches off
new_settings=$(jq -S --arg main "$main_key" --arg client "$client_key" --arg name "$CLIENT_KEY_NAME" \
  --arg dir "$models" --argjson port "$PORT" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  .version = "1.0"
  | .server += {host: "127.0.0.1", port: $port, auto_start_on_launch: false}
  | .model += {model_dirs: [$dir], model_dir: $dir}
  | .memory += {prefill_memory_guard: true, memory_guard_tier: "balanced"}
  | .cache += {enabled: true}
  | .auth += {api_key: $main, skip_api_key_verification: false, allow_unauthenticated_inference: false}
  | .auth.sub_keys = ((.auth.sub_keys // [])
      | if any(.[]; .name == $name) then . else . + [{key: $client, name: $name, created_at: $now}] end)
  ' <<<"$current")
plist=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>UserName</key>
	<string>$SERVICE_USER</string>
	<key>GroupName</key>
	<string>staff</string>
	<key>ProgramArguments</key>
	<array>
		<string>$APP/Contents/MacOS/omlx-cli</string>
		<string>serve</string>
		<string>--base-path</string>
		<string>$base</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>HOME</key>
		<string>$home</string>
		<key>MallocSpaceEfficient</key>
		<string>1</string>
		<key>OMLX_SUPERVISED</key>
		<string>launchd</string>
		<key>PYTHONUNBUFFERED</key>
		<string>1</string>
	</dict>
	<key>WorkingDirectory</key>
	<string>/</string>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ProcessType</key>
	<string>Interactive</string>
	<!-- Longer than the 60 second shutdown of the server, since a SIGKILL leaves GPU memory wired until a restart -->
	<key>ExitTimeOut</key>
	<integer>180</integer>
	<key>ThrottleInterval</key>
	<integer>30</integer>
	<key>StandardOutPath</key>
	<string>$log</string>
	<key>StandardErrorPath</key>
	<string>$log</string>
</dict>
</plist>
EOF
)
if [ "$(jq -S . <<<"$current")" != "$new_settings" ] || [ "$(cat "$plist_file" 2>/dev/null)" != "$plist" ]; then
  # The server rewrites settings.json itself, so it must be stopped before the file changes. bootout can return
  # while launchd still waits for the server to exit, and the Server step would then skip starting it
  sudo launchctl bootout "system/$LABEL" 2>/dev/null || true
  for _ in $(seq 1 200); do
    sudo launchctl print "system/$LABEL" >/dev/null 2>&1 || break
    sleep 1
  done
  printf '%s\n' "$new_settings" | write_as_service 077 "$settings"
  printf '%s\n' "$plist" > "$work/plist"
  plutil -lint "$work/plist" >/dev/null
  sudo install -m 644 -o root -g wheel "$work/plist" "$plist_file"
  echo "Wrote $settings and $plist_file"
else
  echo "Unchanged"
fi

step "Tailscale Serve"
wanted=$(jq -n --arg port "$PORT" --arg paths "$SERVE_PATHS" '
  $paths | split(" ") | map({key: ., value: {Proxy: "http://127.0.0.1:\($port)\(.)"}}) | from_entries')
serve=$(tailscale serve status --json 2>/dev/null || echo '{}')
handlers=$(jq -c --arg h "$fqdn:443" '.Web[$h].Handlers // {}' <<<"$serve")
others=$(jq -r --arg h "$fqdn:443" '((.Web // {}) | keys - [$h]) + ((.TCP // {}) | keys - ["443"]) | .[]' <<<"$serve")
if [ -n "$others" ] || jq -e --argjson w "$wanted" 'keys - ($w | keys) | length > 0' <<<"$handlers" >/dev/null; then
  tailscale serve status >&2 || true
  die "Tailscale Serve publishes more than this setup expects. Clear it with: sudo tailscale serve reset"
fi
for path in $SERVE_PATHS; do
  if [ "$(jq -c --arg p "$path" '.[$p] // null' <<<"$handlers")" != "$(jq -c --arg p "$path" '.[$p]' <<<"$wanted")" ]; then
    sudo tailscale serve --bg --yes --https=443 --set-path="$path" "http://127.0.0.1:$PORT$path" >/dev/null
    echo "Published $path"
  fi
done
for path in $SERVE_PATHS; do echo "https://$fqdn$path"; done

step "Server"
# lsof exits 1 when nothing listens
listening=$(sudo lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)
if [ -n "$(awk -v u="$SERVICE_USER" 'NR > 1 && $3 != u' <<<"$listening")" ]; then
  die "Another program listens on port $PORT. Stop it first: $(tail -n +2 <<<"$listening")"
fi
sudo launchctl print "system/$LABEL" >/dev/null 2>&1 || sudo launchctl bootstrap system "$plist_file"
echo "Waiting for the pinned models to load"
running=""
for _ in $(seq 1 180); do
  curl -fsS -o /dev/null "http://127.0.0.1:$PORT/health" 2>/dev/null && { running=1; break; }
  sleep 10
done
[ -n "$running" ] || die "The server did not become healthy. Its log: $log"
echo "Running"

step "Models for OpenClaw"
models_status=$(curl -fsS -H "Authorization: Bearer $main_key" "http://127.0.0.1:$PORT/v1/models/status")
aliased() { jq -c --arg a "$1" 'first(.models[] | select(.model_alias == $a)) // empty' <<<"$models_status"; }
describe() { jq -r '"\(.id) (\(.model_type), \(if .pinned then "pinned" else "not pinned" end))"' <<<"$1"; }
chat=$(aliased "$CHAT_ALIAS")
embedding=$(aliased "$EMBEDDING_ALIAS")
if [ -n "$chat" ]; then
  chat_id=$(jq -r .id <<<"$chat")
  case "$(jq -r .model_type <<<"$chat")" in
    vlm) chat_input=text,image ;;
    llm) chat_input=text ;;
    *) die "$CHAT_ALIAS is the alias of $(describe "$chat"), which is not a chat model." ;;
  esac
  jq -e '[.max_context_window, .max_tokens] | all(type == "number" and . > 0)' <<<"$chat" >/dev/null ||
    die "oMLX knows no context window or output limit for $chat_id. Set them in Settings > Model Settings."
  chat_context=$(jq -r .max_context_window <<<"$chat")
  chat_max_tokens=$(jq -r .max_tokens <<<"$chat")
  echo "$CHAT_ALIAS: $(describe "$chat"), $chat_context tokens of context, up to $chat_max_tokens out"
else
  echo "$CHAT_ALIAS: no model has this alias"
fi
if [ -n "$embedding" ]; then
  embedding_id=$(jq -r .id <<<"$embedding")
  [ "$(jq -r .model_type <<<"$embedding")" = embedding ] ||
    die "$EMBEDDING_ALIAS is the alias of $(describe "$embedding"), which is not an embedding model."
  echo "$EMBEDDING_ALIAS: $(describe "$embedding")"
else
  echo "$EMBEDDING_ALIAS: no model has this alias"
fi

failed=0
if [ -n "$running" ]; then
  step "Checks"
  check() {
    local description=$1
    shift
    if "$@" >/dev/null 2>&1; then
      echo "ok    $description"
    else
      echo "FAIL  $description"
      failed=1
    fi
  }
  api() { curl -sS --max-time 600 -H "Authorization: Bearer $client_key" -H 'Content-Type: application/json' "$@"; }
  status_ok() {
    curl -fsS -H "Authorization: Bearer $main_key" "http://127.0.0.1:$PORT/api/status" |
      jq -e --arg v "$OMLX_VERSION" '.version == $v and ([.custom_kernels[]?.available] | length > 0 and all)'
  }
  embeds() {
    api "https://$fqdn/v1/embeddings" -d "{\"model\":\"$embedding_id\",\"input\":\"test\"}" |
      jq -e '.data[0].embedding | length > 0'
  }
  chats() {
    api "https://$fqdn/v1/chat/completions" \
      -d "{\"model\":\"$CHAT_ALIAS\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" |
      jq -e '.usage.completion_tokens > 0'
  }
  code_is() {
    local want=$1
    shift
    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$@")
    grep -Eqx "$want" <<<"$code"
  }
  times_out() {
    local out
    out=$(sudo nc -v -z -G 5 "$1" "$2" 2>&1) && return 1
    grep -q 'timed out' <<<"$out"
  }
  # Root is not subject to pf. On a router port that root connects to, the account's connect must fail. On a port
  # the router drops, where root times out, only an immediate refusal shows that pf acted: the reset pf answers
  # with, which does not reach every Mac. A port the router refuses itself shows nothing.
  testable() {
    local out
    root_connects=""
    out=$(sudo nc -v -z -G 5 "$1" "$2" 2>&1) && { root_connects=1; return 0; }
    grep -q 'timed out' <<<"$out"
  }
  turned_away() {
    local out
    out=$(as_service nc -v -z -G 5 "$1" "$2" 2>&1) && return 1
    grep -q 'nc: connectx' <<<"$out" || return 1
    [ -n "$root_connects" ] || ! grep -q 'timed out' <<<"$out"
  }

  # The first HTTPS request makes Tailscale fetch the certificate
  for _ in 1 2 3 4 5 6; do
    curl -sS -o /dev/null --max-time 30 "https://$fqdn/v1/embeddings" 2>/dev/null && break
    sleep 10
  done
  check "oMLX $OMLX_VERSION runs with its native kernels" status_ok
  [ -z "$embedding" ] || check "embeddings from $embedding_id through https://$fqdn" embeds
  [ -z "$chat" ] || check "chat with the alias $CHAT_ALIAS through https://$fqdn" chats
  check "requests without the key are refused" code_is '40[13]' -H 'Content-Type: application/json' \
    -d "{\"model\":\"$EMBEDDING_ALIAS\",\"input\":\"test\"}" "https://$fqdn/v1/embeddings"
  check "the model list is not published" code_is 404 -H "Authorization: Bearer $client_key" "https://$fqdn/v1/models"
  check "the admin pages are not published" code_is 404 "https://$fqdn/admin"
  for ip in $(jq -r '.Peer[] | select(.Online) | .TailscaleIPs[0]' <<<"$ts"); do
    check "tailnet device $ip drops SSH from here, even from root" times_out "$ip" 22
  done
  # pf lets DNS through
  router=$(route -n get default 2>/dev/null | awk '/gateway:/ { print $2 }' || true)
  tested=""
  for port in 80 443; do
    [ -n "$router" ] && testable "$router" "$port" || continue
    check "$SERVICE_USER cannot connect to the router ($router:$port)" turned_away "$router" "$port"
    tested=1
    break
  done
  [ -n "$tested" ] || echo "skip  pf: the router refuses ports 80 and 443 itself, or there is no router"
fi

if [ -n "$chat" ] && [ -n "$embedding" ]; then
  step "Settings for OpenClaw"
  umask 077
  mkdir -p "$HOME/.config/omlx"
  # OpenClaw ties its memory index to the name of the embedding model, so it gets that name rather than the
  # alias and rebuilds the index when it changes. The chat model goes by its alias and can change any time.
  cat > "$HOME/.config/omlx/client.env" <<EOF
OMLX_URL=https://$fqdn/v1
OMLX_API_KEY=$client_key
OMLX_CHAT_MODEL=$CHAT_ALIAS
OMLX_CHAT_INPUT=$chat_input
OMLX_CHAT_CONTEXT=$chat_context
OMLX_CHAT_MAX_TOKENS=$chat_max_tokens
OMLX_EMBEDDING_MODEL=$embedding_id
EOF
  echo "Wrote $HOME/.config/omlx/client.env (scripts/openclaw/setup --omlx reads it)"
fi

echo
if [ -z "$chat" ] || [ -z "$embedding" ]; then
  cat <<EOM
oMLX $OMLX_VERSION runs, but OpenClaw cannot use it yet. In the oMLX admin pages, give the alias $CHAT_ALIAS
to the chat model of the personal agent, and the alias $EMBEDDING_ALIAS to the embedding model for memory search:
  1. From your Mac: ssh -L $PORT:127.0.0.1:$PORT $USER@${fqdn%%.*}
     In that session, show the key to log in with: sudo jq -r .auth.api_key $settings
  2. Open http://localhost:$PORT/admin and log in
  3. Models > Downloader: download the models from Hugging Face
  4. Settings > Model Settings: set Model Alias for both, and pin both
Then run this setup again.
EOM
  exit 1
fi
if [ "$failed" = 0 ]; then
  echo "oMLX $OMLX_VERSION is set up."
else
  echo "oMLX $OMLX_VERSION is set up, but some checks failed (see above)."
fi
echo "It runs as $SERVICE_USER from startup, with nobody logged in."
echo "Next, from your Mac: scripts/openclaw/setup <user@host> --omlx $USER@${fqdn%%.*}"
exit "$failed"
