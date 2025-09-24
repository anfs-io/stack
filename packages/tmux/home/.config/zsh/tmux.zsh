# Tmux

alias mx="tmuxinator"
alias tls="tmux list-sessions"
alias trs="tmux rename-session $1"
alias trw="tmux rename-window $1"
tsw() {
  tmux swap-window -t $1
  tmux select-window -t $1
}
alias tssh='eval $(tmux showenv -s SSH_AUTH_SOCK)'  # Restore connection to the ssh agent socket inside Tmux

ta() {
  if (( $# == 0 )); then
    tmux attach
  else
    tmux attach -t ${1}
  fi
}

tconf() {
  local config_dir=$CONFIG_DIR/tmux
  local file="tmux.conf"

  if [[ $1 == "ls" ]]; then
    ls $config_dir
    return
  fi

  if (( $# == 1 )); then
    file="${1}.conf"
  fi
  (cd $config_dir; nvim ${file})
}
