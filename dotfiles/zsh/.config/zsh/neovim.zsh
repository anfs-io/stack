# Neovim

nconf() {
  local config_dir=$HOME/.config/nvim/lua/plugins

  if [[ $1 == "ls" ]]; then
    ls $config_dir
    return
  fi

  file="init.lua"
  if (( $# == 1 )); then
    file="lua/plugins/${1}.lua"
  fi
  (cd $config_dir; nvim ${file})
}

alias vi=nvim
alias vif='nvim $(fzf -m --preview="batcat --color=always {}")'
