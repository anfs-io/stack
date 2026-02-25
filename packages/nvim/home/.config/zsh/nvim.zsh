# neovim

export EDITOR=nvim

nconf() {
  local dir=$XDG_CONFIG_HOME/nvim/lua/plugins file="../../init.lua" ext="lua"
  if [[ $# == 1 && "$1" == "options" ]]; then
    dir=$dir/..
  fi
  load_conf "$@"
}

alias vi=nvim

vid() {
  if [[ $# -eq 0 ]]; then
    vi -p ./*
  elif [[ $# -eq 1 && -d "$1" ]]; then
    vi -p "$1"/*
  else
    vi -p "$@"
  fi
}

alias vif='nvim $(fzf -m --preview="bat --color=always {}")'

viall() {
  local debug=false
  if [[ "$1" == "-d" ]]; then
    debug=true
    shift
  fi
  local pattern="${1:-*}"
  local files=($(find . -not -path '*/.*' -type f -name "$pattern" | sort))
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No files matching '$pattern'"
    return 1
  fi
  if $debug; then
    echo "Files matching '$pattern':"
    printf '  %s\n' "${files[@]}"
  else
    nvim -p "${files[@]}"
  fi
}
