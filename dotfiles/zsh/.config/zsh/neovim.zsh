# Neovim

nconf() {
  if [[ $1 == "ls" ]]; then
    ls ~/.config/nvim/lua/plugins
  else
    file="init.lua"
    if (( $# == 1 )); then
      file="lua/plugins/${1}.lua"
    fi
    (cd ~/.config/nvim; nvim ${file})
  fi
}

alias vi=nvim
alias vif='nvim $(fzf -m --preview="batcat --color=always {}")'
