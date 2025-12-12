# neovim

export EDITOR=nvim

nconf() {
  local dir=$CONFIG_DIR/nvim/lua/plugins file="../../init.lua" ext="lua"
  if [[ $# == 1 && "$1" == "options" ]]; then
    dir=$dir/..
  fi
  load_conf $1 $2
}

alias vi=nvim
alias vif='nvim $(fzf -m --preview="batcat --color=always {}")'
