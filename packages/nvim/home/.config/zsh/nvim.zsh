# neovim

export EDITOR=nvim

nconf() {
  local dir=$XDG_CONFIG_HOME/nvim/lua/plugins file="../../init.lua" ext="lua"
  if [[ $# == 1 && "$1" == "options" ]]; then
    dir=$dir/..
  fi
  load_conf "$@"
}

alias vi=nvim

vid() {
  if [[ $# -eq 0 ]]; then
    vi -p ./*
  elif [[ $# -eq 1 && -d "$1" ]]; then
    vi -p "$1"/*
  else
    vi -p "$@"
  fi
}

alias vif='nvim $(fzf -m --preview="bat --color=always {}")'
