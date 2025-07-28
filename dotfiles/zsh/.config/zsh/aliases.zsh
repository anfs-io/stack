# custom aliases
#
# echo ${0:a:h} # The dir of this script
export PATH=~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export EDITOR=nvim
bindkey -v

source <(fzf --zsh)

# Claude
alias cl="clear; claude"
alias clc="clear; claude --continue"
alias cldsp="clear; claude --dangerously-skip-permissions"
alias clr="clear; claude --resume"

clu() {
  local base_dir="$HOME/.local/share/npm"
  if [[ "$1" == "-g" ]]; then
    base_dir="/usr/local"
  fi
  (cd "${base_dir}/lib/node_modules/@anthropic-ai"; rm -rf claude-code; npm i -g @anthropic-ai/claude-code)
}

alias clv="claude --version"

# Clasp
alias clp="clasp push"

# Docker
alias dcd="docker compose down"
alias dvls="docker volume ls"

# Git
alias gmv="git mv"
alias gpl="git pull"

# Neovim
nconf() {
  file="init.lua"
  if (( $# == 1 )); then
    file="lua/plugins/${1}.lua"
  fi
  (cd ~/.config/nvim; nvim ${file})
}

alias vi=nvim
alias vif='nvim $(fzf -m --preview="batcat --color=always {}")'



# Tmux
ta() {
  if (( $# == 0 )); then
    tmux attach
  else
    tmux attach -t ${1}
  fi
}
alias tls="tmux list-sessions"

# Restore connection to the ssh agent socket inside Tmux
alias tssh='eval $(tmux showenv -s SSH_AUTH_SOCK)'

alias mx=tmuxinator

# -a shows hidden files; -l follow symlinks; -I ignore
alias tsa="tree -a -l -I tmp -I .git -I .terraform -I .DS_Store -I \"._*\" -I .obsidian -I apps"


# General Aliases and helpers
alias cls="clear"
alias dconf="(cd ~/config/dotfiles; nvim .)"
alias lsar="lsa -R"

zconf() {
  if [[ $1 == "ls" ]]; then
    ls ~/.config/zsh
  else
    file="aliases.zsh"
    if (( $# == 1 )); then
      file="${1}.zsh"
    fi
    (cd ~/.config/zsh; nvim ${file}) # ; cd -
  fi
}

zsrc() {
  for file in ~/.config/zsh/*; do
    source $file
  done
  for file in ~/.config/zsh-ext/*; do
    source $file
  done
}

alias ag="alias | grep ${1}"

# cd to a specific dir and invoke fzf
zcd() {
  export FZF_DEFAULT_COMMAND='find . -type d -not -path "*.git*" -not -path "*tmp*" -not -path "*node_modules*"'
  cd $1
  local res=`fzf`
  if [ -z $res ]; then
    cd -
  else
    cd $res
  fi
  unset FZF_DEFAULT_COMMAND
}


# Tofu workspace function
tws() {
    if [[ $# -eq 0 ]]; then
        tofu workspace show
    else
        tofu workspace select "$1"
    fi
}

# Tofu aliases
alias twls='tofu workspace list'
alias twa='tofu apply'
alias twaa='tofu apply --auto-approve'
alias twp='tofu plan'
