# custom aliases
#
# echo ${0:a:h} # The dir of this script

coder_local() { [[ "$CODER_PROFILE" == "local" ]] }
coder_remote() { [[ "$CODER_PROFILE" == "remote" ]] }

# export PATH=~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Add ~/.local/bin to the search path
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
eval "$(/opt/homebrew/bin/brew shellenv)"
export EDITOR=nvim
bindkey -v

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# Project directories and aliases
export CONFIG_DIR=$HOME/.config
export CODE_DIR=$HOME/code
export PROJECTS_DIR=$CODE_DIR/projects
export PROJECTS_GITHUB_ORG="maxcole"
export PROJECTS_GIT_REMOTE_PREFIX="git@github.com:$PROJECTS_GITHUB_ORG"
export DOTFILES_PATH=rjayroach/coder
export DOTFILES_HOME=$PROJECTS_DIR/$DOTFILES_PATH

config() { cd "$CONFIG_DIR/$1" }
pcs() { cd "$PROJECTS_DIR/pcs/$1" }
rjayroach() { cd "$PROJECTS_DIR/rjayroach/$1" }
roteoh() { cd "$PROJECTS_DIR/roteoh/$1" }
rws() { cd "$PROJECTS_DIR/rws/$1" }

ostype() {
  case "$(uname)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

if [ $(ostype) = "linux" ]; then
  # alias ip_addr="echo $(hostname -I | awk '{print $1}')"
  alias ip_addr="echo $(ip route get 8.8.8.8 | awk '{print $7}' | head -1)"
elif [ $(ostype) = "macos" ]; then
  alias ip_addr="echo $(route get 8.8.8.8 | grep interface | awk '{print $2}' | xargs ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"
fi

if [ $(ostype) = "macos" ]; then
  fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

# Clasp
alias clp="clasp push"

if [ $(ostype) = "linux" ]; then
  alias bat=batcat
fi

# Docker
alias dcd="docker compose down"
alias dvls="docker volume ls"

# -a shows hidden files; -l follow symlinks; -I ignore
alias tsa="tree -a -l -I tmp -I .git -I .terraform -I .DS_Store -I \"._*\" -I .obsidian -I apps"


# General Aliases and helpers
alias cls="clear"
alias lsar="lsa -R"

zconf() {
  # local dir=$(dirname $(readlink -f "${(%):-%x}") )
  local dir="$CONFIG_DIR/zsh"
  if [[ $1 == "ls" ]]; then
    ls $dir
  elif [[ $1 == "pwd" ]]; then
    echo $dir
  else
    file="aliases.zsh"
    if (( $# == 1 )); then
      file="${1}.zsh"
      # if [ ! -f "$dir/$file" ]; then
      #   dir="$CONFIG_DIR/zsh"
      # fi
    fi
    (cd $dir; nvim ${file})
  fi
}

zlinks() {
  local cmd="find \$HOME -type l -exec ls -la {} \\; 2>/dev/null | grep '$DOTFILES_PATH' | awk '{print \$9}'"

  if [[ "$1" == "--delete" ]]; then
    cmd="$cmd | xargs rm"
  fi

  eval $cmd
}

zsrc() {
  # No need to check if files exist since nullglob only returns existing files
  setopt local_options nullglob

  for file in $CONFIG_DIR/zsh/*; do
    source "$file"
  done

  if [[ -d "$CONFIG_DIR/zsh-ext" ]]; then
    for file in $CONFIG_DIR/zsh-ext/*; do
      source "$file"
    done
  fi
}

zupdate() {
  pushd $DOTFILES_HOME &> /dev/null
  if [[ $# -eq 1 && "$1" == "pull" ]]; then
    git pull
  fi
  ./install.sh dotfiles scripts
  zsrc
  popd &> /dev/null
}


# case-insensitive list of defined aliases
ag() {
  if [[ -z "$1" ]]; then
    echo "Usage: ag <pattern>"
    echo "Search for aliases matching the given pattern"
    return 1
  fi

  echo "Aliases matching '$1':"
  alias | grep --color=auto -i "$1" | sort
}
