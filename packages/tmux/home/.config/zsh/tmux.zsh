# Tmux

ta() {
  if (( $# == 0 )); then
    tmux attach
  else
    tmux attach -t ${1}
  fi
}

tconf() {
  local dir=$CONFIG_DIR/tmux file="tmux.conf" ext="conf"
  load_conf $1 $2
}

tsw() {
  tmux swap-window -t $1
  tmux select-window -t $1
}

alias tls="tmux list-sessions"
alias trs="tmux rename-session $1"
alias trw="tmux rename-window $1"
alias tssh='eval $(tmux showenv -s SSH_AUTH_SOCK)'  # Restore connection to the ssh agent socket inside Tmux
