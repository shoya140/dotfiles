# shellcheck shell=bash

DEFAULTS_CONF="$DOTFILES_DIR/macos/defaults.conf"
HOTKEYS_CONF="$DOTFILES_DIR/macos/hotkeys.conf"
SNAPSHOT_IGNORE="$DOTFILES_DIR/macos/snapshot-ignore.conf"
SNAPSHOT_DIR="$STATE_DIR/snapshot"
SNAPSHOT_PY="$DOTFILES_DIR/lib/snapshot.py"

# Parse a [domain] or [domain -currentHost] header into SECTION_HOST and SECTION_DOMAIN
parse_section() {
  local body="${1#\[}"
  body="${body%\]}"
  SECTION_DOMAIN="${body%% *}"
  case "$body" in
    *-currentHost*) SECTION_HOST="-currentHost" ;;
    *) SECTION_HOST="-" ;;
  esac
}

# Expand defaults.conf into lines of host<TAB>domain<TAB>key<TAB>type<TAB>value
defaults_entries() {
  local line key type value
  SECTION_DOMAIN="" SECTION_HOST="-"
  while read -r line; do
    case "$line" in
      \[*\]) parse_section "$line" ;;
      *)
        [ -n "$SECTION_DOMAIN" ] || die "defaults.conf: entry before any [domain] section: $line"
        read -r key type value <<< "$line"
        printf '%s\t%s\t%s\t%s\t%s\n' "$SECTION_HOST" "$SECTION_DOMAIN" "$key" "$type" "$value"
        ;;
    esac
  done < <(read_conf "$DEFAULTS_CONF")
}

defaults_read() { # host domain key
  if [ "$1" = "-currentHost" ]; then
    defaults -currentHost read "$2" "$3" 2>/dev/null || echo "(unset)"
  else
    defaults read "$2" "$3" 2>/dev/null || echo "(unset)"
  fi
}

defaults_write() { # host domain key type value
  if [ "$1" = "-currentHost" ]; then
    defaults -currentHost write "$2" "$3" "-$4" "$5"
  else
    defaults write "$2" "$3" "-$4" "$5"
  fi
}

# Normalize a value for comparison (bool as 1/0, numbers through %g)
normalize_value() { # type value
  case "$1" in
    bool)
      case "$2" in
        1|true|TRUE|yes|YES) echo 1 ;;
        0|false|FALSE|no|NO) echo 0 ;;
        *) echo "$2" ;;
      esac ;;
    int|float) awk -v v="$2" 'BEGIN { if (v ~ /^-?[0-9.]+$/) printf "%g\n", v; else print v }' ;;
    *) echo "$2" ;;
  esac
}

# Convert an actual value back to the notation used in defaults.conf
conf_value() { # type actual
  if [ "$1" = bool ]; then
    case "$2" in 1) echo true ;; 0) echo false ;; *) echo "$2" ;; esac
  else
    echo "$2"
  fi
}

hotkey_enabled() { # id -> true/false (true when not set)
  local v
  v=$(defaults export com.apple.symbolichotkeys - 2>/dev/null \
      | plutil -extract "AppleSymbolicHotKeys.$1.enabled" raw -o - - 2>/dev/null || true)
  [ -n "$v" ] && echo "$v" || echo true
}

hotkey_disable() { # id ascii keycode modifiers
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" "
    <dict>
      <key>enabled</key><false/>
      <key>value</key>
      <dict>
        <key>type</key><string>standard</string>
        <key>parameters</key>
        <array><integer>$2</integer><integer>$3</integer><integer>$4</integer></array>
      </dict>
    </dict>"
}

macos_apply() {
  require_macos
  section "macOS defaults"
  local host domain key type value actual changed=0
  while IFS=$'\t' read -r host domain key type value; do
    actual=$(defaults_read "$host" "$domain" "$key")
    if [ "$(normalize_value "$type" "$actual")" = "$(normalize_value "$type" "$value")" ]; then
      continue
    fi
    defaults_write "$host" "$domain" "$key" "$type" "$value"
    ok "$domain $key: $actual -> $value"
    changed=$((changed + 1))
  done < <(defaults_entries)

  local id ascii keycode mods
  while read -r id ascii keycode mods; do
    [ "$(hotkey_enabled "$id")" = false ] && continue
    hotkey_disable "$id" "$ascii" "$keycode" "$mods"
    ok "hotkey $id disabled"
    changed=$((changed + 1))
  done < <(read_conf "$HOTKEYS_CONF")

  if [ "$changed" -eq 0 ]; then
    ok "all defaults already match"
    return
  fi
  killall Dock Finder SystemUIServer ControlCenter 2>/dev/null || true
  local activate="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
  [ -x "$activate" ] && "$activate" -u
  info "$changed setting(s) written. Some settings require logout or restart to take effect."
}

macos_defaults_check() {
  section "macOS defaults (declared)"
  local host domain key type value actual n=0
  while IFS=$'\t' read -r host domain key type value; do
    actual=$(defaults_read "$host" "$domain" "$key")
    if [ "$(normalize_value "$type" "$actual")" = "$(normalize_value "$type" "$value")" ]; then
      n=$((n + 1))
    else
      drift "$domain $key: declared=$value actual=$actual"
    fi
  done < <(defaults_entries)

  local id ascii keycode mods
  while read -r id ascii keycode mods; do
    if [ "$(hotkey_enabled "$id")" = false ]; then
      n=$((n + 1))
    else
      drift "hotkey $id is enabled (declared: disabled)"
    fi
  done < <(read_conf "$HOTKEYS_CONF")
  ok "$n declared settings match"
}

# Rewrite values that differ from this machine, keeping comments and alignment
macos_defaults_sync() {
  section "macOS defaults (sync from this machine)"
  local tmp="$DEFAULTS_CONF.tmp" line stripped actual changed=0
  local re='^([^[:space:]#]+)([[:space:]]+)([^[:space:]]+)([[:space:]]+)([^#]*[^[:space:]#])(.*)$'
  SECTION_DOMAIN="" SECTION_HOST="-"
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    stripped=$(printf '%s' "$line" | sed -E 's/(^|[[:space:]]+)#.*$//; s/^[[:space:]]+//')
    case "$stripped" in
      "") ;;
      \[*\]) parse_section "$stripped" ;;
      *)
        if [[ "$line" =~ $re ]]; then
          local key="${BASH_REMATCH[1]}" type="${BASH_REMATCH[3]}" value="${BASH_REMATCH[5]}"
          actual=$(defaults_read "$SECTION_HOST" "$SECTION_DOMAIN" "$key")
          if [ "$actual" != "(unset)" ] && \
             [ "$(normalize_value "$type" "$actual")" != "$(normalize_value "$type" "$value")" ]; then
            line="${key}${BASH_REMATCH[2]}${type}${BASH_REMATCH[4]}$(conf_value "$type" "$actual")${BASH_REMATCH[6]}"
            ok "$SECTION_DOMAIN $key: $value -> $(conf_value "$type" "$actual")"
            changed=$((changed + 1))
          fi
        fi
        ;;
    esac
    printf '%s\n' "$line" >> "$tmp"
  done < "$DEFAULTS_CONF"
  mv "$tmp" "$DEFAULTS_CONF"
  [ "$changed" -gt 0 ] || ok "defaults.conf already matches this machine"
}

# Domains to snapshot: the sections of defaults.conf plus symbolichotkeys
snapshot_domains() {
  {
    defaults_entries | cut -f1,2
    [ -s "$HOTKEYS_CONF" ] && printf -- '-\tcom.apple.symbolichotkeys\n'
  } | sort -u
}

snapshot_file() { # host domain
  if [ "$1" = "-currentHost" ]; then
    echo "$SNAPSHOT_DIR/$2.currentHost.json"
  else
    echo "$SNAPSHOT_DIR/$2.json"
  fi
}

snapshot_capture() { # host domain -> stdout
  if [ "$1" = "-currentHost" ]; then
    defaults -currentHost export "$2" -
  else
    defaults export "$2" -
  fi | python3 "$SNAPSHOT_PY" "$2" "$SNAPSHOT_IGNORE"
}

snapshot_check() {
  section "macOS defaults (snapshot diff)"
  ensure_dir "$SNAPSHOT_DIR"
  local host domain file tmp created=0 same=0
  while IFS=$'\t' read -r host domain; do
    file=$(snapshot_file "$host" "$domain")
    tmp="$file.new"
    snapshot_capture "$host" "$domain" > "$tmp"
    if [ ! -f "$file" ]; then
      mv "$tmp" "$file"
      created=$((created + 1))
      continue
    fi
    if diff -q "$file" "$tmp" >/dev/null; then
      rm "$tmp"
      same=$((same + 1))
      continue
    fi
    drift "$domain$([ "$host" = "-currentHost" ] && echo " (currentHost)"): changed since last snapshot (changed in System Settings?)"
    diff -u -L "snapshot" -L "now" "$file" "$tmp" | sed -n '3,60p' | sed 's/^/     /'
    rm "$tmp"
  done < <(snapshot_domains)
  [ "$created" -eq 0 ] || info "$created baseline snapshot(s) created in $SNAPSHOT_DIR"
  [ "$same" -eq 0 ] || ok "$same domain(s) unchanged since last snapshot"
  info "To keep an undeclared change, add it to macos/defaults.conf and run: dotfiles snapshot"
}

snapshot_update() {
  section "macOS defaults (snapshot)"
  ensure_dir "$SNAPSHOT_DIR"
  local host domain
  while IFS=$'\t' read -r host domain; do
    snapshot_capture "$host" "$domain" > "$(snapshot_file "$host" "$domain")"
  done < <(snapshot_domains)
  ok "snapshot baseline updated in $SNAPSHOT_DIR"
}

macos_check() {
  require_macos
  macos_defaults_check
  snapshot_check
}

macos_sync() {
  require_macos
  macos_defaults_sync
  snapshot_update
}
