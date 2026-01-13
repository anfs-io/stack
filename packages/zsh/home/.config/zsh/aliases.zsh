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

# General Aliases and helpers
alias cls="clear"
alias lsar="lsa -R"


tsa() {
  # -a shows hidden files; -l follow symlinks; -I ignore
  tree -a -l -I tmp -I .git -I .terraform -I .obsidian -I .ruby-lsp -I .DS_Store -I "._*" "$@"
}

# Helper: tsa with base dir, optional subdir (first non-flag param), and flags
_tsa_base() {
  local target_dir="$1"
  shift

  # First param: if not a flag, treat as subdir
  if [[ $# -gt 0 && $1 != -* ]]; then
    target_dir="$target_dir/$1"
    shift
  fi

  tsa "$target_dir" "$@"
}

tsac() { _tsa_base "$CONFIG_DIR" "$@"; }
tsap() { _tsa_base "$HOME/.local/share/ppm" "$@"; }


load_conf() {
  if [[ $1 == "ls" ]]; then
    shift
    local flags=() target_dir="$dir"
    while [[ $# -gt 0 ]]; do
      if [[ $1 == -* ]]; then
        flags+=("$1")
      elif [[ -d "$target_dir/$1" ]]; then
        target_dir="$target_dir/$1"
        shift
        # Remaining args are treated as flags
        flags+=("$@")
        break
      fi
      shift
    done
    ls "${flags[@]}" "$target_dir"
  elif [[ $1 == "pwd" ]]; then
    echo $dir
  elif [[ $1 == "rm" ]]; then
    file="$dir/$2.${ext}"
    if [[ $# -eq 2 && -f $file ]]; then
      rm $file
    else
      echo "Invalid file $file"
    fi
  else
    if [[ $# -eq 1 ]]; then
      if [[ -d "$dir/$1" || -z ${ext} ]]; then
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
  if [[ $# == 1 && "$1" == ".zshrc" ]]; then
    ext=""
  fi
  load_conf "$@"
}

zsrc() {
  setopt local_options nullglob extended_glob
  for file in $ZSH_CONFIG/**/*.zsh(N); do
    source "$file" # No need to check if files exist since nullglob only returns existing files
  done
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
