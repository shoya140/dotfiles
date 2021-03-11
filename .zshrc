autoload -Uz compinit vcs_info add-zsh-hook
compinit -u

# history
HISTFILE=~/.zsh_history
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

alias ll="ls -a -l"
alias ls="gls --color"
export PATH=$HOME/bin:$PATH

case ${OSTYPE} in
    darwin*)
        source ${HOME}/dotfiles/mac.zshrc
    ;;
    linux*)
        source ${HOME}/dotfiles/linux.zshrc
    ;;
esac

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
