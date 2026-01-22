# Tmux

ta() {
  if (( $# == 0 )); then
    tmux attach
  else
    tmux attach -t ${1}
  fi
}

# Break current pane into its own window
alias tbp="tmux break-pane"

# Load the tmux configuration
tconf() {
  local dir=$XDG_CONFIG_HOME/tmux file="tmux.conf" ext="conf"
  load_conf "$@"
}

# List server sessions
alias tls="tmux list-sessions"

# Reload the config
alias trc="tmux source-file $XDG_CONFIG_HOME/tmux/tmux.conf"

# Rename session and window
alias trs="tmux rename-session $1"
alias trw="tmux rename-window $1"

# Swap and stay with the pane
alias tsp="tmux swap-pane -D"

# Swap and stay with window by supplying the target to swap to
tsw() {
  tmux swap-window -t $1
  tmux select-window -t $1
}

# Split window and retain current directory even when a symlink
alias tswv='tmux split-window -h -c "$(pwd)"'
alias tswh='tmux split-window -v -c "$(pwd)"'

# Restore connection to the ssh agent socket inside Tmux
alias tssh='eval $(tmux showenv -s SSH_AUTH_SOCK)'
