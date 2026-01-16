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
alias vif='nvim $(fzf -m --preview="batcat --color=always {}")'
