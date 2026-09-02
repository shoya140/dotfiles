# shellcheck shell=bash

LINKS_CONF="$DOTFILES_DIR/links.conf"

resolve_path() { readlink -f "$1" 2>/dev/null || printf '%s\n' "$1"; }

# Expand links.conf into lines of "absolute src<TAB>absolute dst"
link_entries() {
  local src dst item
  while read -r src dst; do
    [ -n "$src" ] && [ -n "$dst" ] || continue
    case "$dst" in
      */)
        for item in "$DOTFILES_DIR"/$src; do
          [ -e "$item" ] || continue
          printf '%s\t%s\n' "$item" "$HOME/${dst}$(basename "$item")"
        done
        ;;
      *) printf '%s\t%s\n' "$DOTFILES_DIR/$src" "$HOME/$dst" ;;
    esac
  done < <(read_conf "$LINKS_CONF")
}

# ok | missing | wrong (symlink to somewhere else) | occupied (regular file or directory)
link_status() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    if [ "$(resolve_path "$dst")" = "$(resolve_path "$src")" ]; then echo ok; else echo wrong; fi
  elif [ -e "$dst" ]; then
    echo occupied
  else
    echo missing
  fi
}

link_apply() {
  section "Symlinks"
  local src dst status changed=0
  local backup_root="$STATE_DIR/backup/$(date +%Y%m%d-%H%M%S)"
  while IFS=$'\t' read -r src dst; do
    if [ ! -e "$src" ]; then
      warn "source not found, skipped: ${src#"$DOTFILES_DIR"/}"
      continue
    fi
    status=$(link_status "$src" "$dst")
    case "$status" in
      ok) continue ;;
      occupied)
        ensure_dir "$backup_root$(dirname "$dst")"
        mv "$dst" "$backup_root$dst"
        info "backed up ~/${dst#"$HOME"/} -> $backup_root$dst"
        ;;
      wrong) rm "$dst" ;;
    esac
    ensure_dir "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "linked ~/${dst#"$HOME"/} -> ${src#"$DOTFILES_DIR"/}"
    changed=$((changed + 1))
  done < <(link_entries)
  [ "$changed" -gt 0 ] || ok "all symlinks already in place"
}

link_check() {
  section "Symlinks"
  local src dst status n=0
  while IFS=$'\t' read -r src dst; do
    status=$(link_status "$src" "$dst")
    case "$status" in
      ok) n=$((n + 1)) ;;
      missing) drift "missing link: ~/${dst#"$HOME"/} (run: dotfiles link)" ;;
      wrong) drift "wrong link: ~/${dst#"$HOME"/} -> $(readlink "$dst") (run: dotfiles link)" ;;
      occupied) drift "not a symlink: ~/${dst#"$HOME"/} (run: dotfiles link)" ;;
    esac
  done < <(link_entries)
  ok "$n symlinks OK"
}
