dotfiles
======================

## Set up

Install homebrew

```
$ xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Clone this repository

```
$ brew install git
$ cd
$ git clone git@github.com:shoya140/dotfiles.git
```

Create aliases

```
$ cd
$ ln -s dotfiles/.zshrc
$ ln -s dotfiles/.gitconfig
$ ln -s dotfiles/.gitignore_global
$ ln -s dotfiles/.vimrc
$ ln -s dotfiles/.gvimrc
# Claude Code
$ mkdir -p ~/.claude/skills
$ ln -sfn ~/dotfiles/agent-config/claude__settings.json ~/.claude/settings.json
$ ln -sfn ~/dotfiles/agent-config/claude__CLAUDE.md ~/.claude/CLAUDE.md
$ ln -sfn ~/dotfiles/agent-config/skills/* ~/.claude/skills/
$ mkdir -p ~/.claude-api/skills
$ ln -sfn ~/dotfiles/agent-config/claude__settings.json ~/.claude-api/settings.json
$ ln -sfn ~/dotfiles/agent-config/claude__CLAUDE.md ~/.claude-api/CLAUDE.md
$ ln -sfn ~/dotfiles/agent-config/skills/* ~/.claude-api/skills/
# Codex
$ mkdir -p ~/.codex/skills
$ ln -sfn ~/dotfiles/agent-config/codex__AGENTS.md ~/.codex/AGENTS.md
$ ln -sfn ~/dotfiles/agent-config/skills/* ~/.codex/skills/
# ghostty
$ ln -s ~/dotfiles/.config/ghostty ~/.config/ghostty
# herdr
$ mkdir -p ~/.config/herdr
$ ln -sf ~/dotfiles/.config/herdr/config.toml ~/.config/herdr/config.toml
```

Change the default shell to zsh

```
$ brew install zsh
$ sudo sh -c "echo '/usr/local/bin/zsh' >> /etc/shells"
$ chsh -s /usr/local/bin/zsh
```

Install brew packages

```
$ xargs brew install < ~/dotfiles/brew_list.txt
```

Install dein

```
$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shougo/dein-installer.vim/master/installer.sh)"
```

karabiner-elements

```
$ mkdir -p ~/.config/karabiner
$ ln -s ~/dotfiles/.config/karabiner/karabiner.json ~/.config/karabiner/karabiner.json
```

## Maintain brew packages

```
$ brew leaves > ~/dotfiles/brew.txt
```
