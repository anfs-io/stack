# Tmux

ta() {
  if (( $# == 0 )); then
    tmux attach
  else
    tmux attach -t ${1}
  fi
}

tconf() {
  local dir=$XDG_CONFIG_HOME/tmux file="tmux.conf" ext="conf"
  load_conf "$@"
}

tsw() {
  tmux swap-window -t $1
  tmux select-window -t $1
}

# Manage sessions, windows and panes
alias tbp="tmux break-pane"
alias tls="tmux list-sessions"
alias trc="tmux source-file $XDG_CONFIG_HOME/tmux/tmux.conf"
alias trs="tmux rename-session $1"
alias trw="tmux rename-window $1"

alias tsv='tmux split-window -h -c "$(pwd)"'
alias tsh='tmux split-window -v -c "$(pwd)"'

# Restore connection to the ssh agent socket inside Tmux
alias tssh='eval $(tmux showenv -s SSH_AUTH_SOCK)'
