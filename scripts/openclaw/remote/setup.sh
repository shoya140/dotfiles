#!/bin/bash
# Runs on the OpenClaw host as the account that runs the gateway. ../setup copies it there and starts it.
set -euo pipefail

OPENCLAW_VERSION=2026.10.4
NODE_MAJOR=26
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
STATE_DIR="$HOME/.openclaw"
CONFIG="$STATE_DIR/openclaw.json"
SETTINGS="$STATE_DIR/setup.env"
NODE_BIN="$HOME/.local/share/mise/installs/node/$NODE_MAJOR/bin/node"
SETTING_NAMES="OWNER_ID OMLX_URL OMLX_CHAT_MODEL OMLX_CHAT_INPUT OMLX_CHAT_CONTEXT OMLX_CHAT_MAX_TOKENS
  OMLX_EMBEDDING_MODEL"

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export MISE_YES=1
# The config is rendered here, so OpenClaw itself must not rewrite it
export OPENCLAW_CONFIG_READONLY=1

omlx_env="" restore=""
while [ $# -gt 0 ]; do
  case "$1" in
    --omlx-env) omlx_env=$2; shift 2 ;;
    --restore) restore=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

step() { printf '\n== %s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }
matches() { grep -Eq "^($2)\$" <<<"$1"; }
env_value() { [ -f "$1" ] && sed -n "s/^$2=//p" "$1" | tail -n 1; }
ask() { local value; read -r -p "$1: " value < /dev/tty; printf '%s' "$value"; }
ask_hidden() { local value; read -r -s -p "$1: " value < /dev/tty; echo > /dev/tty; printf '%s' "$value"; }

step "Checking this Mac"
[ "$(uname -s)" = Darwin ] || die "This is not macOS."
dseditgroup -o checkmember -m "$USER" admin >/dev/null || die "$USER is not an administrator."
launchctl print "gui/$(id -u)" >/dev/null 2>&1 ||
  die "$USER is not logged in to the desktop. Log in with Screen Sharing, lock the screen, then run this again."
[ -x "$HOME/.local/bin/mise" ] || die "mise is missing. Run ~/dotfiles/setup cui first."
command -v tailscale >/dev/null || die "tailscale is missing. Run ~/dotfiles/setup cui first."
ts=$(tailscale status --json) || die "tailscaled is not running."
[ "$(jq -r .BackendState <<<"$ts")" = Running ] || die "Tailscale is not connected. Sign in with: sudo tailscale up"
jq -e '(.Self.Tags // []) | index("tag:openclaw")' <<<"$ts" >/dev/null ||
  die "This Mac does not have the tag tag:openclaw. Apply the tailnet policy and the tag first (README.md)."
jq -e '(.CertDomains // []) | length > 0' <<<"$ts" >/dev/null ||
  die "HTTPS certificates are off for the tailnet. Turn them on in the admin console under DNS."
fqdn=$(jq -r '.Self.DNSName | rtrimstr(".")' <<<"$ts")
echo "$USER on $fqdn"

step "Passwordless sudo for $USER"
sudoers_line="$USER ALL=(ALL) NOPASSWD: ALL"
if [ "$(sudo cat /etc/sudoers.d/openclaw 2>/dev/null)" != "$sudoers_line" ]; then
  printf '%s\n' "$sudoers_line" > "$work/sudoers"
  sudo visudo -cf "$work/sudoers" >/dev/null
  sudo install -m 440 -o root -g wheel "$work/sudoers" /etc/sudoers.d/openclaw
  echo "Wrote /etc/sudoers.d/openclaw"
fi

step "Node.js $NODE_MAJOR and OpenClaw $OPENCLAW_VERSION"
previous=$(openclaw --version 2>/dev/null | awk '{ print $2 }' || true)
mise use -g "node@$NODE_MAJOR" "npm:openclaw@$OPENCLAW_VERSION"
# mise installs npm packages without their install scripts; the first run of openclaw finishes them
installed=$(openclaw --version | awk '{ print $2 }')
[ "$installed" = "$OPENCLAW_VERSION" ] || die "openclaw --version reports $installed, not $OPENCLAW_VERSION."
[ -x "$NODE_BIN" ] || die "$NODE_BIN is missing."
echo "OpenClaw $installed with $("$NODE_BIN" --version)"

step "Google Chrome for the browser tool"
if [ -d "/Applications/Google Chrome.app" ]; then
  echo "Installed"
else
  mise bootstrap packages use -g brew-cask:google-chrome
fi

restored=""
if [ -n "$restore" ]; then
  step "Restoring $(basename "$restore")"
  openclaw backup verify "$restore" >/dev/null
  staging="$HOME/.openclaw-restore-$(date +%Y%m%d%H%M%S)"
  openclaw backup restore "$restore" --target "$staging" --json >/dev/null
  manifest=$(find "$staging" -maxdepth 2 -name manifest.json | head -n 1)
  [ -n "$manifest" ] || die "No manifest.json in $staging"
  root=$(dirname "$manifest")
  state_path=$(jq -r '[.assets[] | select(.kind == "state")][0].archivePath // empty' "$manifest")
  state_source=$(jq -r '[.assets[] | select(.kind == "state")][0].sourcePath // empty' "$manifest")
  [ -n "$state_path" ] && [ -d "$root/$state_path" ] || die "The archive has no state directory."
  jq -r --arg s "$state_source/" '.assets[] | select((.sourcePath + "/" | startswith($s)) | not)
    | "Not restored (outside the state directory): \(.kind) \(.sourcePath)"' "$manifest" >&2
  if launchctl print "gui/$(id -u)/ai.openclaw.gateway" >/dev/null 2>&1; then
    openclaw gateway stop --force
  fi
  if [ -e "$STATE_DIR" ]; then
    aside="$STATE_DIR.before-restore-$(date +%Y%m%d%H%M%S)"
    mv "$STATE_DIR" "$aside"
    echo "Moved the current state to $aside"
  fi
  mv "$root/$state_path" "$STATE_DIR"
  rm -rf "$staging"
  restored=1
  echo "Restored the state from $state_source"
fi
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

step "Settings"
for name in $SETTING_NAMES; do
  value=$(env_value "$SETTINGS" "$name" || true)
  case "$name" in OMLX_*) [ -z "$omlx_env" ] || value=$(env_value "$omlx_env" "$name" || true) ;; esac
  eval "$name=\$value"
done
if [ -z "$OWNER_ID" ]; then
  OWNER_ID=$(ask "Your Telegram user ID (a number; @userinfobot replies with it)")
fi
matches "$OWNER_ID" '[0-9]+' || die "The Telegram user ID must be a number."
[ -n "$OMLX_URL" ] || die "No oMLX settings yet. Run the setup with --omlx <user@host> (README.md)."
omlx_setting() {
  matches "${!1}" "$2" ||
    die "Unexpected $1 '${!1}' in the oMLX settings. Run scripts/omlx/setup again, then this setup with --omlx."
}
omlx_setting OMLX_URL 'https://[A-Za-z0-9.-]+/v1'
omlx_setting OMLX_CHAT_MODEL '[A-Za-z0-9._-]+'
omlx_setting OMLX_CHAT_INPUT 'text(,image)?'
omlx_setting OMLX_CHAT_CONTEXT '[0-9]+'
omlx_setting OMLX_CHAT_MAX_TOKENS '[0-9]+'
omlx_setting OMLX_EMBEDDING_MODEL '[A-Za-z0-9._-]+'
for name in $SETTING_NAMES; do
  eval "printf '%s=%s\n' \"\$name\" \"\$$name\""
done > "$work/settings"
if ! cmp -s "$work/settings" "$SETTINGS"; then
  install -m 600 "$work/settings" "$SETTINGS"
  echo "Wrote $SETTINGS"
fi
echo "Owner $OWNER_ID, oMLX $OMLX_URL (chat: $OMLX_CHAT_MODEL, embeddings: $OMLX_EMBEDDING_MODEL)"

step "Secrets in the OpenClaw secret store"
stored=$(openclaw secrets store list --json | jq -r '.[].name')
has_secret() { grep -qx "$1" <<<"$stored"; }
put_secret() {
  printf '%s' "$2" | openclaw secrets store set "$1" --kind secret >/dev/null
  stored=$(printf '%s\n%s' "$stored" "$1")
  echo "Stored $1"
}
has_secret OPENCLAW_GATEWAY_TOKEN || put_secret OPENCLAW_GATEWAY_TOKEN "$(openssl rand -hex 32)"
if [ -n "$omlx_env" ]; then
  key=$(env_value "$omlx_env" OMLX_API_KEY || true)
  [ -n "$key" ] || die "The oMLX settings have no OMLX_API_KEY."
  put_secret OMLX_API_KEY "$key"
fi
has_secret OMLX_API_KEY || die "No oMLX API key yet. Run the setup with --omlx <user@host>."
for pair in "TELEGRAM_MAIN_BOT_TOKEN:Bot token of the Telegram bot for main" \
  "TELEGRAM_PERSONAL_BOT_TOKEN:Bot token of the Telegram bot for personal" \
  "ANTHROPIC_API_KEY:Anthropic API key" "BRAVE_API_KEY:Brave Search API key"; do
  name=${pair%%:*}
  has_secret "$name" && continue
  value=$(ask_hidden "${pair#*:}")
  [ -n "$value" ] || die "Nothing entered for $name."
  put_secret "$name" "$value"
done

step "Brave search plugin"
if [ -n "$restored" ] || ! openclaw plugins inspect brave >/dev/null 2>&1; then
  # The plugin's own dependencies are not in backups, so a restore installs it again
  env -u OPENCLAW_CONFIG_READONLY openclaw plugins install "@openclaw/brave-plugin@$OPENCLAW_VERSION" \
    --pin --no-enable ${restored:+--force}
else
  echo "Installed"
fi

step "Commands run without approval"
if openclaw approvals get --json |
  jq -e '.file.defaults | .security == "full" and .ask == "off" and .askFallback == "full"' >/dev/null 2>&1; then
  echo "Already set"
else
  openclaw approvals set --stdin <<<'{"version":1,"defaults":{"security":"full","ask":"off","askFallback":"full"}}' >/dev/null
  echo "Set the host approvals to full"
fi

step "Config"
jq --arg owner "$OWNER_ID" --arg url "$OMLX_URL" --arg chat "$OMLX_CHAT_MODEL" \
  --arg embedding "$OMLX_EMBEDDING_MODEL" --arg input "$OMLX_CHAT_INPUT" --argjson context "$OMLX_CHAT_CONTEXT" \
  --argjson max_tokens "$OMLX_CHAT_MAX_TOKENS" --arg home "$HOME" '
  def fill: gsub("__OWNER_ID__"; $owner) | gsub("__OMLX_URL__"; $url)
    | gsub("__CHAT_MODEL__"; $chat) | gsub("__EMBEDDING_MODEL__"; $embedding) | gsub("__HOME__"; $home);
  walk(if type == "object" then with_entries(.key |= fill) elif type == "string" then fill else . end)
  | .models.providers.omlx.models[0].input = ($input | split(","))
  | .models.providers.omlx.models[0].contextWindow = $context
  | .models.providers.omlx.models[0].maxTokens = $max_tokens
  ' "$HERE/openclaw.json" > "$STATE_DIR/openclaw.json.new"
chmod 600 "$STATE_DIR/openclaw.json.new"
if ! OPENCLAW_CONFIG_PATH="$STATE_DIR/openclaw.json.new" openclaw config validate --json > "$work/validate.json"; then
  jq . "$work/validate.json" >&2 || cat "$work/validate.json" >&2
  rm -f "$STATE_DIR/openclaw.json.new"
  die "The rendered config does not validate."
fi
if cmp -s "$STATE_DIR/openclaw.json.new" "$CONFIG"; then
  rm "$STATE_DIR/openclaw.json.new"
  echo "Unchanged"
else
  mv "$STATE_DIR/openclaw.json.new" "$CONFIG"
  echo "Wrote $CONFIG"
fi
jq -r '.warnings[]? | "warning: \(.)"' "$work/validate.json"

if [ -n "$restored" ] || [ "$previous" != "$OPENCLAW_VERSION" ]; then
  step "Doctor (new version or restored state)"
  openclaw doctor --fix --non-interactive || echo "Doctor reported problems; the checks at the end show whether they matter." >&2
  for agent in main personal; do openclaw skills list --agent "$agent" >/dev/null; done
fi

step "Keeping $USER off the local network"
sudo /bin/bash "$HERE/../lib/lan-block.sh" "$USER" openclaw

step "Gateway service"
openclaw gateway install --force --runtime-path "$NODE_BIN" >/dev/null
for _ in $(seq 1 90); do
  curl -fsS -o /dev/null http://127.0.0.1:18789/readyz 2>/dev/null && break
  sleep 2
done
curl -fsS -o /dev/null http://127.0.0.1:18789/readyz || {
  openclaw gateway status --deep --json >&2 || true
  die "The gateway is not ready. Its log: ~/Library/Logs/openclaw/gateway.log"
}
openclaw gateway status --deep --require-rpc >/dev/null
echo "Ready at https://$fqdn/"

step "Checks"
failed=0
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
answers() {
  openclaw infer model run --gateway --agent "$1" --model "$2" --prompt "Reply with exactly: pong" --json |
    jq -e '.outputs[0].text | test("pong"; "i")'
}
# OpenClaw pauses vector search when the embedding model differs from the one the index was built with;
# --index rebuilds such an index, and otherwise only catches up with changed files
memory_ready() {
  openclaw memory status --index --agent "$1" --json |
    jq -e '.[0] | .embeddingProbe.ok == true and .indexError == null'
}
# A device that receives a connection the tailnet policy does not grant drops it, so the attempt times out;
# a refusal would mean the packet got through
times_out() {
  local out
  out=$(sudo nc -v -z -G 5 "$1" "$2" 2>&1) && return 1
  grep -q 'timed out' <<<"$out"
}
# Root is not subject to pf. On a router port that root connects to, the account's connect must fail. On a port the
# router drops, where root times out, only an immediate refusal shows that pf acted: the reset pf answers with,
# which does not reach every Mac. A port the router refuses itself shows nothing.
testable() {
  local out
  root_connects=""
  out=$(sudo nc -v -z -G 5 "$1" "$2" 2>&1) && { root_connects=1; return 0; }
  grep -q 'timed out' <<<"$out"
}
turned_away() {
  local out
  out=$(nc -v -z -G 5 "$1" "$2" 2>&1) && return 1
  grep -q 'nc: connectx' <<<"$out" || return 1
  [ -n "$root_connects" ] || ! grep -q 'timed out' <<<"$out"
}

audit=$(openclaw security audit --json)
check "security audit has no critical findings" jq -e '.summary.critical == 0' <<<"$audit"
jq -r '.findings[] | select(.severity != "info") | "      \(.severity) \(.checkId): \(.title)"' <<<"$audit"
check "secrets audit" openclaw secrets audit --check
check "main answers with anthropic/claude-haiku-5-5" answers main anthropic/claude-haiku-5-5
check "personal answers with omlx/$OMLX_CHAT_MODEL" answers personal "omlx/$OMLX_CHAT_MODEL"
check "the memory index of main matches $OMLX_EMBEDDING_MODEL" memory_ready main
check "the memory index of personal matches $OMLX_EMBEDDING_MODEL" memory_ready personal
check "Telegram accounts pass the probe" openclaw channels status --probe
# The agents keep their own speech command; setup only points OpenClaw at it
tts_command=$(jq -r '.tts.providers["tts-local-cli"].command // empty' "$CONFIG")
[ -z "$tts_command" ] || check "the speech command $tts_command exists" test -x "$tts_command"
check "the Control UI answers through Tailscale Serve" curl -sS -o /dev/null --max-time 30 "https://$fqdn/"

omlx_host=$(printf '%s' "$OMLX_URL" | sed -E 's|^https://([^/]+)/v1$|\1|')
check "the oMLX host answers on 443" curl -sS -o /dev/null --max-time 10 "https://$omlx_host/"
check "the oMLX host drops SSH from here, even from root" times_out "$omlx_host" 22
for ip in $(jq -r '.Peer[] | select(.Online and ((.Tags // []) | index("tag:omlx") | not)) | .TailscaleIPs[0]' <<<"$ts"); do
  check "tailnet device $ip drops SSH from here, even from root" times_out "$ip" 22
done
# pf is only a seatbelt here, since root can turn it off; this checks that it is in place. It lets DNS through.
router=$(route -n get default 2>/dev/null | awk '/gateway:/ { print $2 }' || true)
tested=""
for port in 80 443; do
  [ -n "$router" ] && testable "$router" "$port" || continue
  check "$USER cannot connect to the router ($router:$port)" turned_away "$router" "$port"
  tested=1
  break
done
[ -n "$tested" ] || echo "skip  pf: the router refuses ports 80 and 443 itself, or there is no router"

echo
if [ "$failed" = 0 ]; then
  echo "OpenClaw $OPENCLAW_VERSION is set up."
else
  echo "OpenClaw $OPENCLAW_VERSION is set up, but some checks failed (see above)."
fi
cat <<EOM

Manual steps left:
  - Open https://$fqdn/ from your own Mac to reach the Control UI
  - Send a message to both bots in Telegram
  - In @BotFather, set /setjoingroups to Disable for both bots
EOM
[ -z "$restored" ] || echo "  - Delete $STATE_DIR.before-restore-* once the restored state looks right"
exit "$failed"
