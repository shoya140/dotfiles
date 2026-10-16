dotfiles
======================

Declarative macOS setup on [mise](https://mise.jdx.dev): packages, dotfiles, macOS `defaults` and tools are
declared in TOML and applied with `mise bootstrap`. Every Mac takes `base` plus exactly one role.

## Roles

| Role | Kind of Mac | Includes |
| --- | --- | --- |
| `workstation` | used with a display and keyboard, and kept on as a server | gui, always-on, dev |
| `mobile` | a laptop carried around | gui, dev |
| `server` | a headless server used over SSH | always-on, headless, dev |
| `agent` | a headless Mac for an AI agent (OpenClaw), with its own Apple Account | always-on, headless |
| `shared-llm` | a headless LLM server shared with others, no Apple Account | always-on, headless |

Machine names, hardware and which Mac has which role are not recorded here. A Mac's role is the link in
`~/.config/mise/conf.d` (`mise config ls` shows it).

## Layout

| Path | Declares |
| --- | --- |
| `base/mise.toml` | what every Mac gets: CLI packages, macOS defaults, staying awake on AC power, every dotfile, dein.vim |
| `base/home/`, `base/agent-config/` | the dotfiles themselves, linked into `$HOME` |
| `parts/*.toml` | pieces the roles include: `gui` (GUI and App Store apps including the Tailscale app, trackpad), `always-on` (wake for network access, restart after a power failure), `headless` (the Tailscale daemon), `dev` (tools and CLI) |
| `roles/<role>/mise.toml` | a role: the parts it includes plus its own packages and tools |
| `setup` | sets up a Mac for a role |
| `check` | the part of the weekly check that mise has no command for |
| `base/scripts/` | hooks that `mise bootstrap` runs (restarting Dock and Finder, power settings, starting the Tailscale daemon), and helpers for `check` |

`setup` links `base` and the role into `~/.config/mise/conf.d`, where mise reads them as global config.
Dotfiles are linked through those two links (`~/.zshrc -> ~/.config/mise/conf.d/base/home/.zshrc`), so a
moved repository only needs the two links updated.

## Set up a new Mac

1. By hand in System Settings:
   - General > About: set the computer name
   - General > Sharing: turn on Screen Sharing and Remote Login
   - Privacy & Security: turn FileVault on or off. dotfiles leaves it alone. A Mac with FileVault on waits for
     the password at its own screen after a restart, so a Mac reached over Tailscale keeps it off
   - App Store: sign in when the role has App Store apps (workstation and mobile: the personal Apple Account,
     agent: the agent's Apple Account, shared-llm: none)
2. In a terminal:

   ```
   xcode-select --install
   git clone https://github.com/shoya140/dotfiles.git ~/dotfiles
   ~/dotfiles/setup <role>
   ```

`setup` installs Homebrew and mise (`~/.local/bin/mise`) when they are missing, links `base` and the role,
and runs `mise bootstrap`, which asks for confirmation and the sudo password. It ends with the manual steps
left for the role, such as signing in to Tailscale. Every step is idempotent, so it is safe to run again.

To replace a Mac, read the old one's role with `mise config ls` and set up the new one with the same role.

## Commands

After `setup`, everything is a mise command.

| To | Run |
| --- | --- |
| apply the repo to this Mac | `mise bootstrap` (`--dry-run` previews) |
| see the state of everything declared | `mise bootstrap status` |
| declare packages and install them | `mise bootstrap packages use -p ~/dotfiles/<file> <package>...` (`--no-install` only declares) |
| upgrade the declared packages and tools | `mise bootstrap --update --upgrade` |
| see this Mac's role | `mise config ls` |

`<file>` is `base/mise.toml`, `parts/<part>.toml` or `roles/<role>/mise.toml`, and a package is
`brew:<formula>`, `brew-cask:<token>` or `mas:<id>`.

To bring another Mac up to date: `git -C ~/dotfiles pull && mise bootstrap`. A change to dotfiles alone needs
only the pull.

## Weekly maintenance

Run `/dotfiles` in Claude Code about once a week. It runs the commands below, walks through each item and asks
where to declare it. Nothing runs automatically. By hand:

```
git -C ~/dotfiles pull
mise bootstrap --dry-run                               # declared but not in place on this Mac
mise bootstrap packages prune --dry-run                # formulae that no config declares
mise bootstrap packages prune --dry-run -m brew-cask   # casks that no config declares
~/dotfiles/check                                       # what mise has no command for
```

`prune --dry-run` only lists. Without `--dry-run` it uninstalls every formula that no config declares, including
ones installed with Homebrew itself. Casks installed with Homebrew show up as `skipped: Homebrew owns this cask`.

`check` covers:

1. App Store apps installed but not declared
2. the tracked `defaults` domains changed since the last snapshot, which is how a setting changed in System
   Settings shows up before it is declared (`check --accept` takes the current preferences as the snapshot)
3. entries in the Mac's own `~/.config/mise/config.toml`

Typical flows:

```
$ brew install --cask foo                                # try an app
$ mise bootstrap packages prune --dry-run -m brew-cask   # it shows up as not declared
$ mise bootstrap packages use -p ~/dotfiles/parts/gui.toml brew-cask:foo   # keep it on every Mac with a display

$ ~/dotfiles/check                  # a setting changed in System Settings shows up in the snapshot diff
$ vim ~/dotfiles/base/mise.toml     # declare it (or ignore the key in base/scripts/snapshot-ignore.conf)
$ ~/dotfiles/check --accept         # take the new preferences as the snapshot
```

## Notes

- `parts/*.toml` are config includes. They can hold `[bootstrap]`, `[tools]` and hooks but not `[dotfiles]`,
  which makes mise reject the whole config, so every dotfile is declared in `base/mise.toml`. A config file for
  an app the Mac does not have is simply unused.
- A mistake in any of these files stops mise on every Mac that loads it. Run `mise bootstrap --dry-run` before
  committing.
- The files need mise 2026.10.11 or later (`min_version` in `base/mise.toml`); `setup` installs that version.
  `mise self-update` updates it. Try a new version on one Mac before the others.
- mise installs packages itself instead of calling `brew`. Formulae land in `/opt/homebrew` with Homebrew
  receipts, so `brew` manages them too, but casks installed by mise are upgraded by mise
  (`mise bootstrap --upgrade`). Homebrew stays installed for trying things and for the rare cask mise cannot
  install, and `brew upgrade` updates what it installed.
- Power settings go through `sudo pmset -c` (AC power only) in `base/scripts/power.sh`, and only for the values
  that differ. Every Mac stays awake on AC power; the always-on roles also wake for network access and restart
  after a power failure where the Mac supports it.
- Tailscale comes in two forms. The Macs with a display (`gui`) get the Tailscale app, which joins the tailnet
  only after someone logs in. The headless roles get the open source daemon (`brew:tailscale`), which
  `base/scripts/tailscaled.sh` starts once with `sudo brew services start tailscale`, so the Mac joins at boot.
  Sign in with `sudo tailscale up`. The daemon leaves DNS alone, so MagicDNS names need `100.100.100.100` as a
  DNS server. After an upgrade, `sudo brew services restart tailscale` runs the new version. The hook does not
  start the daemon while the Tailscale app is installed: both keep their state in `/Library/Tailscale`, so a Mac
  that switches to the daemon removes the app with `brew uninstall --zap --cask tailscale-app` first.
- macOS defaults are compared with their type, so an integer 1 does not satisfy `true`. The hooks in
  `base/scripts/defaults-hook.sh` restart Dock, Finder and the menu bar only when a run changed their
  preferences. Some settings need a logout or restart.
- `mise use -g` writes the Mac's own `~/.config/mise/config.toml`, which is not in this repo. `check` lists its
  entries so that they can move to base, a part or a role.
- Snapshots live in `~/.local/state/dotfiles/snapshot/`.
