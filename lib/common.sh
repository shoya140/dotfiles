# shellcheck shell=bash
# Shared helpers sourced by bin/dotfiles. Keep everything compatible with the bash 3.2 that ships with macOS.

STATE_DIR="${DOTFILES_STATE_DIR:-$HOME/.local/state/dotfiles}"
DRIFT_COUNT=0
DRIFT_SUMMARY=""

if [ -t 1 ]; then
  C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_BLUE=$'\033[34m' C_RESET=$'\033[0m'
else
  C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_RESET=""
fi

section() { printf '\n%s== %s ==%s\n' "$C_BLUE" "$1" "$C_RESET"; }
info()    { printf '   %s\n' "$*"; }
ok()      { printf '%s ✓ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn()    { printf '%s ! %s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
die()     { printf '%s ✗ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

drift() {
  DRIFT_COUNT=$((DRIFT_COUNT + 1))
  DRIFT_SUMMARY="${DRIFT_SUMMARY}${1}"$'\n'
  printf '%s ✗ %s%s\n' "$C_RED" "$1" "$C_RESET"
  if [ $# -gt 1 ]; then
    shift
    printf '%s\n' "$@" | sed 's/^/     /'
  fi
}

# Print a config file without comments (# at line start or after whitespace) and blank lines
read_conf() {
  [ -f "$1" ] || return 0
  sed -E 's/(^|[[:space:]]+)#.*$//' "$1" | sed -E '/^[[:space:]]*$/d'
}

# Items of the whitespace-separated list $1 that are not in $2
list_minus() {
  comm -23 <(printf '%s\n' $1 | sort -u) <(printf '%s\n' $2 | sort -u)
}

ensure_dir() { [ -d "$1" ] || mkdir -p "$1"; }

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "This command only supports macOS"
}
