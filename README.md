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
```

Change the default shell to zsh

```
$ brew install zsh
$ sudo sh -c "echo '/usr/local/bin/zsh' >> /etc/shells"
$ chsh -s /usr/local/bin/zsh
```

Install brew packages

```
$ xargs brew install < ~/dotfiles/brew.txt
```

Install dein

```
$ curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
$ sh ./installer.sh ~/.cache/dein
$ rm installer.sh
```

karabiner-elements

```
$ ln -s ~/dotfiles/karabiner.json ~/.config/karabiner/karabiner.json
```

## Maintain brew packages

```
$ brew leaves > ~/dotfiles/brew.txt
```
