---
name: dotfiles
description: Review the output of dotfiles check and resolve drift by updating the repo (sync) or applying the repo to the machine
disable-model-invocation: true
allowed-tools: Bash(dotfiles check), Bash(dotfiles sync), Bash(dotfiles snapshot), Bash(git status), Bash(git diff *), Bash(git log *), Bash(defaults read *), Bash(defaults -currentHost read *)
---

Resolve the drift between the declarations in ~/dotfiles and this machine.

Optional arguments: $ARGUMENTS. Follow them if they restrict the work to specific items.

Steps:

1. Run `dotfiles check` and report the drift grouped by kind:
   - Repository: uncommitted, unpushed, or behind origin
   - Symlinks: missing links, or links replaced by regular files
   - Packages: differences between packages/*.txt and the machine (brew, cask, mas)
   - macOS defaults (declared): values in macos/defaults.conf that differ from the machine
   - macOS defaults (snapshot diff): changes to undeclared keys, which are candidates for settings changed in System Settings
2. For each item, ask the user whether to update the repo from the machine (`dotfiles sync`) or apply the repo to the machine (`dotfiles packages` / `macos` / `link`). Suggest a choice when it is obvious, such as a newly installed app.
3. For snapshot diff entries that turn out to be intentional settings, add them to the matching domain in macos/defaults.conf in the same format as the other lines (a one-line comment in English followed by `key type value`). Infer the type from the `defaults read` output (1/0 means bool). Add keys that are unknown or change on their own to macos/snapshot-ignore.conf.
4. After editing, run `dotfiles snapshot` to update the baseline, then `dotfiles check` again to confirm the drift is gone.
5. Summarize the changes. Leave committing to /commit (this skill does not commit).

Notes:

- `dotfiles sync` overwrites packages/*.txt with this machine's state, so entries that are declared but not installed disappear. Say so before running it.
- Applying to the machine (`dotfiles macos` and so on) rewrites settings, so the user runs those commands. Do not run them from this skill.
