alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

peco_search_history() {
    local l=$(HISTTIMEFORMAT= history | \
                  sed -e 's/^[0-9\| ]\+//' -e 's/ \+$//' | \
                  tac | \
                  peco --query "$READLINE_LINE")
    READLINE_LINE="$l"
    READLINE_POINT=${#l}
}
bind -x '"\C-r": peco_search_history'

