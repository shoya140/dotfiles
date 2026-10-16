#!/bin/bash
# Run around the macOS defaults step of mise bootstrap. `pre` records the preference domains that Dock,
# Finder and the menu bar read at launch; `post` restarts them only when mise changed one of those domains.
set -euo pipefail

DOMAINS="NSGlobalDomain com.apple.dock com.apple.finder com.apple.WindowManager com.apple.screencapture com.apple.menuextra.clock com.apple.symbolichotkeys"
STAMP="${TMPDIR:-/tmp}/dotfiles-defaults-$(id -u)"

digest() {
  local domain
  for domain in $DOMAINS; do
    defaults export "$domain" - 2>/dev/null || true
  done
  defaults -currentHost export NSGlobalDomain - 2>/dev/null || true
  defaults -currentHost export com.apple.controlcenter - 2>/dev/null || true
}

case "${1:-}" in
  pre)
    digest | shasum > "$STAMP"
    ;;
  post)
    [ -f "$STAMP" ] || exit 0
    before=$(cat "$STAMP")
    rm -f "$STAMP"
    [ "$(digest | shasum)" != "$before" ] || exit 0
    killall Dock Finder SystemUIServer ControlCenter 2>/dev/null || true
    activate=/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings
    if [ -x "$activate" ]; then
      "$activate" -u
    fi
    echo "Restarted Dock, Finder and the menu bar to load the changed defaults. Some settings need a logout."
    ;;
  *)
    echo "usage: $0 pre|post" >&2
    exit 1
    ;;
esac
