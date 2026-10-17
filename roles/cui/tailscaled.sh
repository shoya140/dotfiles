#!/bin/bash
# Start tailscaled as a system daemon (sudo brew services) unless it is registered already, so that sudo is
# asked for only once.
set -euo pipefail

launchctl print system/homebrew.mxcl.tailscale >/dev/null 2>&1 && exit 0

# Run only one Tailscale client per Mac. Both keep their state in /Library/Tailscale, and the tailscale CLI
# talks to the app while the app's files are there, so the app has to go with --zap.
if [ -d /Applications/Tailscale.app ]; then
  echo "Not starting tailscaled: the Tailscale app is installed. Remove it with" >&2
  echo "  brew uninstall --zap --cask tailscale-app" >&2
  echo "then run mise bootstrap again." >&2
  exit 0
fi

echo "Starting tailscaled as a system daemon"
sudo "$(command -v brew)" services start tailscale
