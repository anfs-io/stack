# Tmux

alias mx=tmuxinator

alias tls="tmux list-sessions"

alias trw="tmux rename-window $1"

# Restore connection to the ssh agent socket inside Tmux
alias tssh='eval $(tmux showenv -s SSH_AUTH_SOCK)'

ta() {
  if (( $# == 0 )); then
    tmux attach
  else
    tmux attach -t ${1}
  fi
}

tconf() {
  local config_dir=$HOME/.config/tmux
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
