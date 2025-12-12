# custom aliases
#
# echo ${0:a:h} # The dir of this script

# export PATH=~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Add ~/.local/bin to the search path
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

# Load homebrew zsh functions
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

bindkey -v

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

export CONFIG_DIR=$HOME/.config

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

# Is this redundant to loading homebrew zsh functions at top of file?
if [ $(ostype) = "macos" ]; then
  fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

# Clasp
alias clp="clasp push"

if [ $(ostype) = "linux" ]; then
  alias bat=batcat
fi

# -a shows hidden files; -l follow symlinks; -I ignore
alias tsa="tree -a -l -I tmp -I .git -I .terraform -I .obsidian -I .ruby-lsp -I .DS_Store -I \"._*\""

# General Aliases and helpers
alias cls="clear"
alias lsar="lsa -R"

load_conf() {
  if [[ $1 == "ls" ]]; then
    ls $2 $dir
  elif [[ $1 == "pwd" ]]; then
    echo $dir
  else
    if [[ $# -eq 1 ]]; then
      if [[ -d "$dir/$1" ]]; then
        file="${1}"
      else
        file="${1}.${ext}"
      fi
    fi
    (cd $dir; ${EDITOR:-vi} ${file})
  fi
}

zconf() {
  local dir=$CONFIG_DIR/zsh file="aliases.zsh" ext="zsh"
  load_conf $1 $2
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
