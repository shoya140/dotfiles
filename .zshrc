if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

autoload -Uz compinit vcs_info add-zsh-hook
compinit -u

# history
HISTFILE=~/Dropbox/active/config/.zsh_history
HISTSIZE=6000000
SAVEHIST=6000000
setopt hist_ignore_dups
setopt share_history

# prompt
zstyle ':vcs_info:*' enable git svn
zstyle ':vcs_info:*' max-exports 6
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' formats '%b@%r' '%c' '%u'
setopt prompt_subst
zstyle ':vcs_info:git:*' actionformats '%b@%r|%a' '%c' '%u'
PROMPT='%F{yellow}[`uname -m`:%~]%f `vcs_echo`
%(?.$.%F{red}$%f) '

function vcs_echo {
    local st branch color
    STY= LANG=en_US.UTF-8 vcs_info
    st=`git status 2> /dev/null`
    if [[ -z "$st" ]]; then return; fi
    branch="$vcs_info_msg_0_"
    if   [[ -n "$vcs_info_msg_1_" ]]; then color=${fg[green]} #staged
    elif [[ -n "$vcs_info_msg_2_" ]]; then color=${fg[red]} #unstaged
    elif [[ -n `echo "$st" | grep "^Untracked"` ]]; then color=${fg[blue]} # untracked
    else color=${fg[cyan]}
    fi
    echo "%{$color%}(%{$branch%})%{$reset_color%}"
}

# alias
alias ll="ls -a -l"
alias ls="gls --color"
alias x="/usr/local/bin/zsh"
alias cot="open $1 -a /Applications/CotEditor.app"

case ${OSTYPE} in
    darwin*)
        export PATH=$HOME/bin:$PATH

        # brew
        if [[ `uname -m` == 'arm64' ]]; then
            export BREW_ROOT=/opt/homebrew
        else
            export BREW_ROOT=/usr/local
        fi

        export PATH=$BREW_ROOT/bin:$BREW_ROOT/sbin:$PATH
        fpath=($BREW_ROOT/share/zsh-completions $fpath)

        # git
        export PATH=$BREW_ROOT/share/git-core/contrib/diff-highlight:$PATH
        function git-ignore-delete(){ git rm --cached `git ls-files -i --full-name --exclude-from=.gitignore`}

        # android
        export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
        export PATH=$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH

        # heroku
        export PATH=$BREW_ROOT/heroku/bin:$PATH

        # opencv
        export PATH=$BREW_ROOT/opt/opencv@3/bin:$PATH
        export LDFLAGS=-L$BREW_ROOT/opt/opencv@3/lib
        export CPPFLAGS=-I$BREW_ROOT/opt/opencv@3/include
        export PKG_CONFIG_PATH=$BREW_ROOT/opt/opencv@3/lib/pkgconfig

        # ruby
        export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"
        export LDFLAGS="-L/opt/homebrew/opt/readline/lib"
        export CPPFLAGS="-I/opt/homebrew/opt/readline/include"
        export PKG_CONFIG_PATH="/opt/homebrew/opt/readline/lib/pkgconfig"
        export optflags="-Wno-error=implicit-function-declaration"
        export LDFLAGS="-L/opt/homebrew/opt/libffi/lib"
        export CPPFLAGS="-I/opt/homebrew/opt/libffi/include"
        export PKG_CONFIG_PATH="/opt/homebrew/opt/libffi/lib/pkgconfig"

        # dart
        export PATH="$PATH":"$HOME/.pub-cache/bin"
    ;;
esac

# docker
function docker-rm-all(){ docker rm $(docker ps -a -q); }
function docker-rmi-all(){ docker rmi $(docker images -q); }
function docker-stop-all(){ docker stop $(docker ps -a -q); }
if type docker-machine >/dev/null 2>&1; then
    if [ $(docker-machine ls --filter "state=running" -q) ]; then
        eval "$(docker-machine env $(docker-machine ls --filter "state=running" -q))"
    fi
fi

# aws
function ec2-instances() { aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | "\(.Tags[].Value)\t\(.State.Name)\t\(.PublicDnsName)"'}
function ec2-ssh(){ ssh -i ~/aws.pem ubuntu@$(aws ec2 describe-instances | jq -r --arg name "$1" '.Reservations[].Instances[] | {Tags, PublicDnsName} | select(.Tags[].Value==$name) | {PublicDnsName} | .[]')}

# Google Cloud SDK
if [ -f "${HOME}/.google-cloud-sdk/path.zsh.inc" ]; then . "${HOME}/.google-cloud-sdk/path.zsh.inc"; fi
if [ -f "${HOME}/.google-cloud-sdk/completion.zsh.inc" ]; then . "${HOME}/.google-cloud-sdk/completion.zsh.inc"; fi

# peco
function peco-select-history() {
    local tac
    if which tac > /dev/null; then
        tac="tac"
    else
        tac="tail -r"
    fi
    BUFFER=$(\history -n 1 | \
        eval $tac | \
        awk '!a[$0]++' | \
        peco --query "$LBUFFER")
    CURSOR=$#BUFFER
    zle clear-screen
}
zle -N peco-select-history
bindkey '^R' peco-select-history

# other scripts
if [ -f "${HOME}/.asdf/asdf.sh" ]; then . "${HOME}/.asdf/asdf.sh"; fi
if [ -f "${HOME}/key.zshrc" ]; then . "${HOME}/key.zshrc"; fi

function conda-activate() {
    local conda_envs=$(conda info -e | awk '{print $1}' | grep -v "#")
    conda activate $(peco <<< ${conda_envs})
}
alias conda-deactivate="conda deactivate"

source '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
source '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'
