if [[ `uname -m` == 'arm64' ]]; then
    export BREW_ROOT=/opt/homebrew
else
    export BREW_ROOT=/usr/local
fi

. $HOME/.asdf/asdf.sh

# alias
alias x="/usr/local/bin/zsh"
alias cot="open $1 -a /Applications/CotEditor.app"
alias cd_font="cd ~/Library/Fonts"

# brew
export PATH=$BREW_ROOT/bin:$PATH
export PATH=$BREW_ROOT/sbin:$PATH
fpath=($BREW_ROOT/share/zsh-completions $fpath)

# heroku
export PATH=$BREW_ROOT/heroku/bin:$PATH

# android
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export PATH=$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH

# git
export PATH=$BREW_ROOT/share/git-core/contrib/diff-highlight:$PATH
function git-ignore-delete(){ git rm --cached `git ls-files -i --full-name --exclude-from=.gitignore`}

# aws
function ec2-instances() { aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | "\(.Tags[].Value)\t\(.State.Name)\t\(.PublicDnsName)"'}
function ec2-ssh(){ ssh -i ~/Dropbox/config/aws.pem ubuntu@$(aws ec2 describe-instances | jq -r --arg name "$1" '.Reservations[].Instances[] | {Tags, PublicDnsName} | select(.Tags[].Value==$name) | {PublicDnsName} | .[]')}

# docker
function docker-rm-all(){ docker rm $(docker ps -a -q); }
function docker-rmi-all(){ docker rmi $(docker images -q); }
function docker-stop-all(){ docker stop $(docker ps -a -q); }

if type docker-machine >/dev/null 2>&1; then
    if [ $(docker-machine ls --filter "state=running" -q) ]; then
        eval "$(docker-machine env $(docker-machine ls --filter "state=running" -q))"
    fi
fi

# Google Cloud SDK
if [ -f "${HOME}/.google-cloud-sdk/path.zsh.inc" ]; then . "${HOME}/.google-cloud-sdk/path.zsh.inc"; fi
if [ -f "${HOME}/.google-cloud-sdk/completion.zsh.inc" ]; then . "${HOME}/.google-cloud-sdk/completion.zsh.inc"; fi

# my secret keys
case ${OSTYPE} in
    darwin*)
        source $HOME/Dropbox/config/key.zshrc
    ;;
esac

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

function peco-cdr () {
    local selected_dir=$(cdr -l | awk '{ print $2 }' | peco)
    if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-cdr
bindkey '^u' peco-cdr
