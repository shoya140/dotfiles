# shellcheck shell=bash

PKG_DIR="$DOTFILES_DIR/packages"

pkg_declared() { read_conf "$PKG_DIR/$1" | awk '{print $1}'; }

# Look up the name of id $1 in the "id  name" list $2
pkg_name() { printf '%s\n' "$2" | awk -v id="$1" '$1 == id { $1 = ""; sub(/^ +/, ""); print; exit }'; }

installed_taps()     { brew tap; }
installed_formulae() { brew list --formula -1; }
leaf_formulae()      { brew leaves; }
installed_casks()    { brew list --cask -1; }
installed_mas_ids()  { mas list 2>/dev/null | awk '{print $1}'; }
mas_available()      { command -v mas >/dev/null 2>&1; }

# Turn "id  Name (version)" lines from mas list into "id  Name"
mas_list_clean() {
  mas list 2>/dev/null | sed -E 's/ +\([^)]*\)$//' | awk '{id=$1; $1=""; sub(/^ +/, ""); print id "  " $0}'
}

packages_install() {
  section "Packages"
  local missing t id
  missing=$(list_minus "$(pkg_declared brew_tap.txt)" "$(installed_taps)")
  for t in $missing; do brew tap "$t"; done

  missing=$(list_minus "$(pkg_declared brew.txt)" "$(installed_formulae)")
  if [ -n "$missing" ]; then
    info "installing formulae:" $missing
    brew install $missing
  fi

  missing=$(list_minus "$(pkg_declared brew_cask.txt)" "$(installed_casks)")
  if [ -n "$missing" ]; then
    info "installing casks:" $missing
    brew install --cask $missing
  fi

  if mas_available; then
    missing=$(list_minus "$(pkg_declared mas.txt)" "$(installed_mas_ids)")
    for id in $missing; do
      mas install "$id" || warn "mas install $id failed (are you signed in to the App Store?)"
    done
  fi
  ok "packages are installed"
}

# $1: label, $2: declared, $3: installed (for missing), $4: candidates for undeclared,
# $5: optional display names as "id  name" lines
pkg_compare() {
  local label="$1" names="${5:-}" missing extra
  missing=$(list_minus "$2" "$3")
  extra=$(list_minus "$4" "$2")
  if [ -n "$names" ]; then
    [ -z "$missing" ] || missing=$(printf '%s\n' $missing | while read -r id; do printf '%s  %s\n' "$id" "$(pkg_name "$id" "$(read_conf "$PKG_DIR/mas.txt")")"; done)
    [ -z "$extra" ]   || extra=$(printf '%s\n' $extra | while read -r id; do printf '%s  %s\n' "$id" "$(pkg_name "$id" "$names")"; done)
  fi
  [ -z "$missing" ] || drift "$label: declared but not installed (run: dotfiles packages)" "$missing"
  [ -z "$extra" ]   || drift "$label: installed but not declared (run: dotfiles sync)" "$extra"
  [ -n "$missing$extra" ] || ok "$label: in sync ($(printf '%s\n' $2 | sed '/^$/d' | wc -l | tr -d ' ') declared)"
}

packages_check() {
  section "Packages"
  local taps casks mas_ids
  taps=$(installed_taps)
  casks=$(installed_casks)
  pkg_compare "tap"  "$(pkg_declared brew_tap.txt)"  "$taps"  "$taps"
  pkg_compare "brew" "$(pkg_declared brew.txt)"      "$(installed_formulae)" "$(leaf_formulae)"
  pkg_compare "cask" "$(pkg_declared brew_cask.txt)" "$casks" "$casks"
  if mas_available; then
    mas_ids=$(installed_mas_ids)
    pkg_compare "mas"  "$(pkg_declared mas.txt)"     "$mas_ids" "$mas_ids" "$(mas_list_clean)"
  else
    warn "mas not found, App Store apps were not checked"
  fi
}

packages_sync() {
  section "Packages (sync from this machine)"
  installed_taps | LC_ALL=C sort > "$PKG_DIR/brew_tap.txt"
  leaf_formulae  | LC_ALL=C sort > "$PKG_DIR/brew.txt"
  installed_casks | LC_ALL=C sort > "$PKG_DIR/brew_cask.txt"
  if mas_available; then
    mas_list_clean | LC_ALL=C sort -k2 > "$PKG_DIR/mas.txt"
  fi
  ok "package lists regenerated in packages/"
}
