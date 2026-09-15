# neovim

export EDITOR=nvim

nconf() {
  local dir=$XDG_CONFIG_HOME/nvim/lua/plugins file="../../init.lua" ext="lua"
  if [[ $# == 1 && "$1" == "options" ]]; then
    dir=$dir/..
  fi
  load_conf "$@"
}

alias vi="nvim -p"

# Open files in the current dir (or a given dir), each in its own tab.
vid() {
  if [[ $# -eq 0 ]]; then
    vi ./*
  elif [[ $# -eq 1 && -d "$1" ]]; then
    vi "$1"/*
  else
    vi "$@"
  fi
}

alias vif='nvim $(fzf -m --preview="bat --color=always {}")'

# Recursively open every matching regular file from the cwd down, each in its
# own tab. Optional trailing arg is a basename glob (default: all files).
#   viall             open every file under . (skips hidden files/dirs)
#   viall '*.rb'      only Ruby files
#   viall -a          include hidden files/dirs (e.g. dotfiles under .config)
#   viall -n '*.rb'   dry run: just list what would open
viall() {
  emulate -L zsh
  setopt extended_glob null_glob

  local dry=false all=false
  while [[ "$1" == -* ]]; do
    case "$1" in
      -n|-d) dry=true ;;
      -a)    all=true ;;
      --)    shift; break ;;
      *)     print -u2 "viall: unknown option '$1'"; return 2 ;;
    esac
    shift
  done

  local pat="${1:-*}"
  # Recursive glob: regular files only (.), N = no error on zero matches.
  # Null-safe with spaces/newlines in names. (D) also matches hidden entries.
  local -a files
  if $all; then
    files=( ./**/${~pat}(D.N) )    # include hidden files/dirs
  else
    files=( ./**/${~pat}(.N) )     # skip hidden files/dirs
  fi

  # Prune ignored dirs/globs (shared with tsa via $PPM_IGNORE_DIRS).
  local -a ignore=( "${PPM_IGNORE_DIRS[@]}" )
  (( ${#ignore} )) || ignore=( .git )
  local p
  for p in "${ignore[@]}"; do
    files=( ${files:#*/${~p}/*} )  # matching directory component
    files=( ${files:#*/${~p}} )    # matching basename
  done

  if (( ${#files} == 0 )); then
    print -u2 "viall: no files matching '${pat}'"
    return 1
  fi

  if $dry; then
    print "Files matching '${pat}':"
    printf '  %s\n' "${files[@]}"
  else
    # -p"${#files}" forces one tab per file (plain -p caps at tabpagemax=10).
    nvim -p"${#files}" -- "${files[@]}"
  fi
}
