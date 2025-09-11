# custom aliases
#
# echo ${0:a:h} # The dir of this script
export PATH=~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export EDITOR=nvim
bindkey -v


if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# Clasp
alias clp="clasp push"

alias bat=batcat

# Docker
alias dcd="docker compose down"
alias dvls="docker volume ls"


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
alias lsar="lsa -R"

zinstall() {
  $HOME/rjayroach/home/install.sh dotfiles scripts
}

zconf() {
  local dir=$(dirname $(readlink -f "${(%):-%x}") )
  if [[ $1 == "ls" ]]; then
    ls $dir
  elif [[ $1 == "pwd" ]]; then
    echo $dir
  else
    file="aliases.zsh"
    if (( $# == 1 )); then
      file="${1}.zsh"
    fi
    (cd $dir; nvim ${file})
  fi
}

zsrc() {
  setopt local_options nullglob
  for file in $HOME/.config/zsh/*; do
    source "$file"  # No need to check -f since nullglob only returns existing files
    # [[ -f "$file" ]] && source "$file"
  done
  if [[ -d "$HOME/.config/zsh-ext" ]]; then
    for file in $HOME/.config/zsh-ext/*; do
      source "$file"  # No need to check -f since nullglob only returns existing files
    done
  fi
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

# Function to ensure a line exists in a file
# Usage: line_in_file <filename> <line>
# Set VERBOSE=true to enable output messages
line_in_file() {
  local filename="$1"
  local line="$2"

  # Validate arguments
  if [ $# -ne 2 ]; then
    echo "Usage: line_in_file <filename> <line>" >&2
    return 1
  fi

  # Create file if it doesn't exist
  touch "$filename"

  # Check if line already exists
  if grep -Fxq "$line" "$filename"; then
    verbose "Line already exists in ${filename}: $line"
  else
    # Line doesn't exist, append it
    echo "$line" >> "$filename"
    verbose "Added line to ${filename}: $line"
  fi
}
