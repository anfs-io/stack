# custom aliases
#
# echo ${0:a:h} # The dir of this script
export PATH=~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export EDITOR=nvim
bindkey -v

source <(fzf --zsh)

# Claude
alias clc="clear; claude"
clu() {
 (cd /usr/local/lib/node_modules/@anthropic-ai; rm -rf claude-code; npm i -g @anthropic-ai/claude-code)
}

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
  tmux attach -t ${1}
}
alias tls="tmux list-sessions"
# -a shows hidden files; -l follow symlinks; -I ignore
alias tsa="tree -a -l -I .git -I tmp -I claude-commands -I .DS_Store -I ._.DS_Store"

alias mx=tmuxinator


# General Aliases and helpers
alias cls="clear"
alias dconf="(cd ~/config/dotfiles; nvim .)"
alias lsar="lsa -R"

zconf() {
  file="aliases.zsh"
  if (( $# == 1 )); then
    file="${1}.zsh"
  fi
  (cd ~/.config/zsh; nvim ${file}) # ; cd -
}

zsrc() {
  for file in ~/.config/zsh/*; do
    source $file
  done
}

alias ag="alias | grep ${1}"

cda() { zcd "$HOME/dev/apps" }
cdb() { zcd "$HOME/dev/business" }
cdc() { zcd "$HOME/.config" }
cdd() { zcd "$HOME/dev" }
cdl() { zcd "$HOME/dev/lab" }
cdmc() { zcd "$HOME/config" }
cdn() { zcd "$HOME/notes" }
cdo() { zcd "$HOME/dev/ops" }
cdp() { zcd "$HOME/pen" }
cds() { zcd "$HOME/services" }

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

cdh() {
echo '
cda() { zcd "$HOME/dev/apps" }
cdc() { zcd "$HOME/.config" }
cdl() { zcd "$HOME/dev/lab" }
cdmc() { zcd "$HOME/config" }
cdn() { zcd "$HOME/notes" }
cdo() { zcd "$HOME/dev/ops" }
cdp() { zcd "$HOME/pen" }
cds() { zcd "$HOME/services" }
'
}

# Para shell function wrapper
para() {
  if [[ "$1" == "cd" ]]; then
    if [[ -z "$2" ]]; then
      echo "Usage: para cd REPO_NAME"
      return 1
    fi

    local target_dir
    target_dir=$(command para cd-path "$2" 2>/dev/null)

    if [[ -n "$target_dir" && -d "$target_dir" ]]; then
      echo "Changing to: $target_dir"
      cd "$target_dir" || return 1
    else
      echo "Repository not found: $2"
      return 1
    fi
  else
    command para "$@"
  fi
}
