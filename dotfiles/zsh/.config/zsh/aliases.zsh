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
  rm -rf "${base_dir}/lib/node_modules/@anthropic-ai/claude-code"
  npm i -g @anthropic-ai/claude-code
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

# git add, commit, push
gacp() {
  local message=""
  vared -p "Git commit message: " message
  git add .
  git commit -m "${message}"
  git push
}

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


# Tofu functions
tf() {
  # Check if TF_BIN is already set
  if [[ -z "$TF_BIN" ]]; then
    # Check for tofu first, then terraform
    if command -v tofu >/dev/null 2>&1; then
      export TF_BIN=tofu
    elif command -v terraform >/dev/null 2>&1; then
      export TF_BIN=terraform
    else
      echo "Error: Neither 'tofu' nor 'terraform' found in PATH"
      return 1
    fi
  fi

  ${TF_BIN} "$@"
}

alias tf-console='tf console'
alias tf-init='tf init'
alias tf-state-list='tf state list'
alias tf-state-show='tf state show'
alias tf-workspace-delete='tf workspace delete'
alias tf-workspace-list='tf workspace list'
alias tf-workspace-new='tf workspace new'
alias tf-workspace-select='tf workspace select'
alias tf-workspace-show='tf workspace show'

tf-apply() { _tf_exec "apply" "$1" }
tf-apply-auto() { _tf_exec "apply" "$1" "-auto-approve" }
tf-destroy() { _tf_exec "destroy" "$1" }
tf-destroy-target() { _tf_exec "destroy" "$1" "-target" "$2"}
tf-plan() { _tf_exec "plan" "$1" }

_tf_exec() {
  local action="$1"
  local extra_args="$3"  # Add support for extra arguments
  local space
  local var_file_arg=""

  # If parameter provided, use it; otherwise use current workspace
  if [[ -n "$2" ]]; then
    space="$2"

    # Switch to the specified workspace
    if ! tf workspace select ${space}; then
      return 1
    fi
  else
    # Use current workspace
    space=$(tf workspace show)
  fi

  # Check if tfvars file exists
  if [[ ! -f "workspace/${space}.tfvars" ]]; then
    # Require a tfvars file unless its the default workspace
    if [[ "$space" != "default" ]]; then
      echo "Error: workspace/${space}.tfvars file not found"
      return 1
    fi
  else
    # File exists, so include it in the command
    var_file_arg="-var-file=workspace/${space}.tfvars"
  fi

  # Execute the terraform/tofu command
  tf ${action} ${var_file_arg} ${extra_args}
}
