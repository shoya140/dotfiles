dotfiles
======================

Declarative macOS setup on [mise](https://mise.jdx.dev): packages, dotfiles, macOS `defaults` and tools are
declared in TOML and applied with `mise bootstrap`. Every Mac takes `base` plus one role.

## Roles

| Role | Kind of Mac | Adds to base |
| --- | --- | --- |
| `gui` | used at its display | GUI and App Store apps, development tools, trackpad settings, the Tailscale app |
| `cui` | nobody logs in to it, used over SSH | the Tailscale daemon, waking for network access, starting up after a power failure |

This repo records neither which Mac has which role nor what only one Mac needs. A Mac's role is its link in
`~/.config/mise/conf.d` (`mise config ls` shows it), and what only it needs goes in its own
`~/.config/mise/config.toml`, which `mise use -g` and `mise bootstrap packages use -g` write to. `mise bootstrap`
applies that file along with the repo.

## Layout

| Path | Contents |
| --- | --- |
| `base/mise.toml` | what every Mac gets: CLI packages, macOS defaults, power settings, every dotfile, dein.vim |
| `base/home/`, `base/agent-config/` | the dotfiles, linked into `$HOME` |
| `base/scripts/` | hooks for `mise bootstrap` (restarting Dock and Finder, power settings) and helpers for `check` |
| `roles/<role>/` | a role's `mise.toml`, and for `cui` the hook that starts the Tailscale daemon |
| `setup` | sets up a Mac for a role |
| `check` | the part of the weekly check that mise has no command for |

`setup` links `base` and the role into `~/.config/mise/conf.d`, where mise reads them as global config. Dotfiles
are linked through those links (`~/.zshrc -> ~/.config/mise/conf.d/base/home/.zshrc`), so a moved repository
only needs the two links updated.

## Set up a new Mac

1. By hand in System Settings:
   - General > About: set the computer name
   - General > Sharing: turn on Screen Sharing and Remote Login
   - Privacy & Security: turn FileVault off on a Mac reached over Tailscale, since with FileVault on it waits
     at its own screen for the password after a restart. dotfiles leaves FileVault alone
   - App Store: sign in on a `gui` Mac
2. In a terminal:

   ```
   xcode-select --install
   git clone https://github.com/shoya140/dotfiles.git ~/dotfiles
   ~/dotfiles/setup <role>
   ```

`setup` installs Homebrew and mise (`~/.local/bin/mise`) when they are missing, links `base` and the role, and
runs `mise bootstrap`, which asks for confirmation and the sudo password. It ends with the manual steps left,
such as signing in to Tailscale. It is safe to run again.

To replace a Mac, set up the new one with the old one's role and copy over the old one's
`~/.config/mise/config.toml`.

## Commands

| To | Run |
| --- | --- |
| apply the repo to this Mac | `mise bootstrap` (`--dry-run` previews) |
| see the state of everything declared | `mise bootstrap status` |
| declare packages in the repo and install them | `mise bootstrap packages use -p ~/dotfiles/<file> <package>...` (`--no-install` only declares) |
| install packages or tools on this Mac only | `mise bootstrap packages use -g <package>...`, `mise use -g <tool>` |
| upgrade the declared packages and tools | `mise bootstrap --update --upgrade` |
| see this Mac's role | `mise config ls` |

`<file>` is `base/mise.toml` or `roles/<role>/mise.toml`, and a package is `brew:<formula>`,
`brew-cask:<token>` or `mas:<id>`.

To bring another Mac up to date: `git -C ~/dotfiles pull && mise bootstrap`. A change to dotfiles alone needs
only the pull.

## Weekly maintenance

Run `/dotfiles` in Claude Code about once a week. It runs the commands below, walks through each item and asks
where to declare it. By hand:

```
git -C ~/dotfiles pull
mise bootstrap --dry-run                               # declared but not in place on this Mac
mise bootstrap packages prune --dry-run                # formulae that no config declares
mise bootstrap packages prune --dry-run -m brew-cask   # casks that no config declares
~/dotfiles/check                                       # App Store apps and System Settings
```

`prune --dry-run` only lists. Without `--dry-run` it uninstalls every formula that no config declares, including
ones installed with Homebrew itself. Casks installed with Homebrew show up as `skipped: Homebrew owns this cask`.

`check` lists App Store apps that no config declares, and the tracked `defaults` domains that changed since the
last snapshot, which is how a setting changed in System Settings shows up before it is declared.
`check --accept` takes the current preferences as the snapshot (in `~/.local/state/dotfiles/snapshot/`).

```
$ brew install --cask foo                                # try an app
$ mise bootstrap packages prune --dry-run -m brew-cask   # it shows up as not declared
$ mise bootstrap packages use -p ~/dotfiles/roles/gui/mise.toml brew-cask:foo   # keep it on every gui Mac
$ mise bootstrap packages use -g brew-cask:foo                               # or on this Mac only

$ ~/dotfiles/check                  # a setting changed in System Settings shows up in the snapshot diff
$ vim ~/dotfiles/base/mise.toml     # declare it (or ignore the key in base/scripts/snapshot-ignore.conf)
$ ~/dotfiles/check --accept         # take the new preferences as the snapshot
```

## Notes

- A mistake in any of these files stops mise on every Mac that loads it. Run `mise bootstrap --dry-run` before
  committing.
- The files need mise 2026.10.11 or later (`min_version` in `base/mise.toml`), the version `setup` installs.
  `mise self-update` updates it; try a new version on one Mac before the others.
- mise installs packages itself instead of calling `brew`. Formulae land in `/opt/homebrew` with Homebrew
  receipts, so `brew` manages them too, but casks installed by mise are upgraded by mise
  (`mise bootstrap --upgrade`). Homebrew stays for trying things and for the rare cask mise cannot install.
- macOS defaults are compared with their type, so an integer 1 does not satisfy `true`.
  `base/scripts/defaults-hook.sh` restarts Dock, Finder and the menu bar only when a run changed their
  preferences. Some settings need a logout or restart.
- Power: `base/scripts/power.sh` sets AC power options with `sudo pmset -c`, only those the Mac supports and
  that differ. Every Mac stays awake on AC power (`sleep 0`). `cui` adds waking for network access (`womp 1`)
  and starting up when power returns after a failure (`autorestart 1`, desktop Macs only).
- Tailscale: the app on `gui` joins the tailnet only after someone logs in. The open source daemon on `cui`
  (`brew:tailscale`, started once with `sudo brew services start tailscale`) joins at boot; sign in with
  `sudo tailscale up`, and after an upgrade run `sudo brew services restart tailscale`. The daemon leaves DNS
  alone, so MagicDNS names need `100.100.100.100` as a DNS server. The app and the daemon share
  `/Library/Tailscale`, so the hook does not start the daemon while the app is installed; remove it with
  `brew uninstall --zap --cask tailscale-app` first.
