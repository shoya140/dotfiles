dotfiles
======================

Declarative macOS setup: symlinks, Homebrew / App Store packages, macOS `defaults`,
and a drift check to run by hand. Everything is driven by `bin/dotfiles`.

## Layout

| Path | Declares |
| --- | --- |
| `links.conf` | symlinks from this repo into `$HOME` |
| `packages/brew_tap.txt`, `brew.txt`, `brew_cask.txt`, `mas.txt` | Homebrew taps, formulae, casks, App Store apps |
| `macos/defaults.conf` | `defaults` settings (`[domain]` sections, `key type value` lines) |
| `macos/hotkeys.conf` | system keyboard shortcuts to disable |
| `macos/snapshot-ignore.conf` | keys ignored by the snapshot diff |
| `.zshrc`, `.gitconfig`, `.vimrc`, `.config/...` | the config files themselves |
| `agent-config/` | Claude Code / Codex settings and skills |
| `bin/dotfiles`, `lib/` | the CLI (bash 3.2 compatible, no dependencies beyond macOS + Homebrew) |

## Set up a new Mac

```
$ xcode-select --install
$ git clone https://github.com/shoya140/dotfiles.git ~/dotfiles
$ ~/dotfiles/bin/dotfiles install
```

`install` installs Homebrew if needed, then runs `packages`, `link`, `tools` and `macos` in order.
Every step is idempotent, so it is also the way to bring an existing machine up to date.
Sign in to the App Store beforehand so that `mas install` works. Some macOS settings need a logout
or restart. Afterwards `dotfiles` is on PATH via `~/.local/bin`.

## Commands

| Command | Direction | What it does |
| --- | --- | --- |
| `dotfiles check` | read only | reports drift between the repo and this machine |
| `dotfiles sync` | machine to repo | regenerates `packages/*.txt`, rewrites changed values in `macos/defaults.conf`, refreshes the snapshot baseline. Review `git diff`, then commit |
| `dotfiles packages` / `link` / `macos` / `tools` | repo to machine | applies one part of the declaration |
| `dotfiles snapshot` | | accepts the current `defaults` state as the new baseline |

## Weekly maintenance

Run `dotfiles check` about once a week, or `/dotfiles` in Claude Code, which runs the check and
walks through each item asking whether to update the repo or apply the repo to the machine.
Nothing runs automatically. The check covers:

1. the repo is committed, pushed and not behind origin
2. every symlink in `links.conf` points into the repo
3. installed taps, formulae, casks and App Store apps match `packages/`
4. every value in `macos/defaults.conf` and `macos/hotkeys.conf` matches `defaults`
5. the tracked `defaults` domains have not changed since the last snapshot. This is how a setting
   changed in System Settings shows up before it is declared

Typical flow after changing something in System Settings:

```
$ dotfiles check            # the snapshot diff shows the changed key
$ vim macos/defaults.conf   # declare it (or add it to macos/snapshot-ignore.conf)
$ dotfiles snapshot         # accept the new baseline
$ git commit
```

Snapshots live in `~/.local/state/dotfiles/snapshot/`. Files replaced by `dotfiles link` are kept
under `~/.local/state/dotfiles/backup/`.

## Notes

- `macos/defaults.conf`: `[domain]` or `[domain -currentHost]` headers, then `key type value`
  lines. Types are `bool`, `int`, `float`, `string`. `dotfiles macos` writes only values that differ.
- Package lists are plain sorted lists (`brew leaves`, `brew list --cask`, `mas list`). `sync`
  overwrites them with this machine's state, so check `git diff` when a machine intentionally lacks
  something.
- To add a config file: put it in the repo and add a line to `links.conf`, then run `dotfiles link`.
