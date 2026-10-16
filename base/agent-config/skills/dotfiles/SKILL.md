---
name: dotfiles
description: Review the drift between ~/dotfiles and this machine and resolve it by declaring this machine's state in the repo or applying the repo to the machine
disable-model-invocation: true
allowed-tools: Bash(git -C ~/dotfiles fetch), Bash(git -C ~/dotfiles status*), Bash(git -C ~/dotfiles diff*), Bash(git -C ~/dotfiles log *), Bash(mise config ls), Bash(mise bootstrap --dry-run), Bash(mise bootstrap status*), Bash(mise bootstrap packages prune --dry-run*), Bash(mise bootstrap packages use --no-install *), Bash(~/dotfiles/check), Bash(~/dotfiles/check --accept), Bash(defaults read *), Bash(defaults read-type *), Bash(defaults -currentHost read *)
---

Resolve the drift between the declarations in ~/dotfiles and this machine.

Optional arguments: $ARGUMENTS. Follow them if they restrict the work to specific items.

Everything is declared in mise config: `base/mise.toml` (every Mac), `parts/*.toml` (`gui`, `always-on`, `headless`, `dev`, included by roles) and `roles/<role>/mise.toml` (one per kind of Mac). `mise config ls` lists `conf.d/<role>/mise.toml`, which names this machine's role, and the role file's `include` line names its parts.

Steps:

1. Run these and report the drift grouped by kind:
   - `git -C ~/dotfiles fetch` and `git -C ~/dotfiles status -sb`: uncommitted, unpushed, or behind origin
   - `mise bootstrap --dry-run`: what the repo declares but this machine does not have yet
   - `mise bootstrap packages prune --dry-run` and `mise bootstrap packages prune --dry-run -m brew-cask`: formulae and casks that no config declares (casks installed with Homebrew appear as "skipped: Homebrew owns this cask")
   - `~/dotfiles/check`: App Store apps not declared, System Settings changes since the last snapshot, and entries in this machine's own ~/.config/mise/config.toml
2. For each item, ask the user whether to declare it in the repo, apply the repo to the machine, or remove it from the machine. Suggest a choice when it is obvious, such as a newly installed app.
3. To declare a package, choose where it belongs and say why: `base/mise.toml` (every Mac), `parts/gui.toml` (every Mac with a display; all GUI apps go here), `parts/dev.toml` (command-line development tools), `parts/always-on.toml`, `parts/headless.toml` (Macs nobody logs in to), or `roles/<role>/mise.toml` (only this kind of Mac). Then run `mise bootstrap packages use --no-install -p ~/dotfiles/<file> <manager>:<name>` with brew:<formula>, brew-cask:<token> or mas:<id>, and add the app name as a trailing comment on a mas line.
4. For snapshot diff entries that turn out to be intentional settings, add them under `[bootstrap.macos.defaults."<domain>"]` in base/mise.toml (parts/gui.toml for trackpad and other settings that only matter with a display), with a one-line English comment above the key. Use the TOML type that `defaults read-type` reports (boolean, integer, float, string); a current-host preference goes in a `[[bootstrap.macos.defaults_entries]]` table with `host = "current"`. Add keys that are unknown or change on their own to base/scripts/snapshot-ignore.conf.
5. Never put `[dotfiles]` in parts/*.toml: mise rejects the whole config. After editing, run `mise bootstrap --dry-run` to confirm that mise still loads the config and plans no unexpected change, then `~/dotfiles/check --accept` and `~/dotfiles/check` again.
6. Summarize the changes. Leave committing to /commit (this skill does not commit).

Notes:

- Declaring in base or a part changes every Mac that includes it. Say so when choosing.
- Applying to the machine (`mise bootstrap`) installs packages, rewrites settings and may ask for the sudo password, so the user runs it. Do not run it from this skill.
- Never run `mise bootstrap packages prune` without `--dry-run`: it uninstalls packages.
