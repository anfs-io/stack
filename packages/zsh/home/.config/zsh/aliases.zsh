# aliases.zsh
# echo ${0:a:h} # The dir of this script

# XDG directories
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=~/.local/state

# non XDG directories
export BIN_DIR=$HOME/.local/bin
export LIB_DIR=$HOME/.local/lib

# Homebrew on PATH, wherever it is installed. This file loads first, so every other .zsh file
# can use brew tools; it runs before $BIN_DIR is added so ~/.local/bin stays first on PATH
if [[ -z $HOMEBREW_PREFIX ]]; then
  for _brew_prefix in /opt/homebrew /home/linuxbrew/.linuxbrew; do
    if [[ -x $_brew_prefix/bin/brew ]]; then
      eval "$($_brew_prefix/bin/brew shellenv zsh)"
      break
    fi
  done
  unset _brew_prefix
fi

ensure_path() {
  local target="$1"
  # Strip target from start, middle, and end of PATH
  local clean_path=":$PATH:"
  clean_path="${clean_path//:$target:/:}"
  clean_path="${clean_path#:}"
  clean_path="${clean_path%:}"

  export PATH="$target${clean_path:+:$clean_path}"
}


# Add $BIN_DIR to the search path
ensure_path "$BIN_DIR"

export PPM_FPATH=$XDG_DATA_HOME/omz/custom/completions

# Write a completion file for <cmd> to $PPM_FPATH if <cmd> is installed and the file is missing
# Packages call this from their own .zsh file; `zsrc -c <cmd>` forces a refresh
# Usage: zcomp <cmd> [generator args...]   (default args: completion zsh)
zcomp() {
  local cmd=$1 file=$PPM_FPATH/_$1
  shift
  (( $+commands[$cmd] )) && [[ -n $PPM_FPATH && ! -s $file ]] || return 0
  (( $# )) || set -- completion zsh
  mkdir -p $PPM_FPATH
  if command $cmd "$@" > $file.tmp 2>/dev/null && [[ -s $file.tmp ]]; then
    mv $file.tmp $file
  else
    rm -f $file.tmp
  fi
}

os() {
  case "$(uname)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

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
    if [[ $# -eq 2 && ( -f $file || -L $file ) ]]; then
      rm $file
    else
      echo "Invalid file $file"
    fi
  elif [[ $1 == "bat" ]]; then
    file="$dir/$2.${ext}"
    if [[ -f $file ]]; then
      bat $file
    else
      echo "Invalid file $file"
    fi
  elif [[ $1 == "cd" ]]; then
    cd "$dir"
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

zsrc() {
  # Handle the optional -c flag
  local opt run_compinit=0
  local OPTIND=1 # Reset OPTIND locally so repeated calls work correctly

  while getopts "c" opt; do
    case "$opt" in
      c) run_compinit=1 ;;
      *) return 1 ;;
    esac
  done
  shift $((OPTIND - 1)) # Remove the parsed flag, leaving extra arguments in $@

  # Original logic to source the files
  setopt local_options nullglob extended_glob
  for file in $ZSH_CONFIG/**/*.zsh(N); do
    source "$file" # No need to check if files exist since nullglob only returns existing files
  done

  # If -c was passed, regenerate the completion file: zsrc -c <cmd> [generator args...]
  if (( run_compinit && $# > 0 )); then
    rm -f "$PPM_FPATH/_$1"
    zcomp "$@"
  fi

  # Re-initialize completion system to register the changes
  autoload -Uz compinit
  compinit
}
