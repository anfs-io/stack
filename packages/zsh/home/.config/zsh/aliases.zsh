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

# Add $BIN_DIR to the search path
[[ ":$PATH:" != *":$BIN_DIR:"* ]] && export PATH="$BIN_DIR:$PATH"

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

zsrc() {
  setopt local_options nullglob extended_glob
  for file in $ZSH_CONFIG/**/*.zsh(N); do
    source "$file" # No need to check if files exist since nullglob only returns existing files
  done
}
