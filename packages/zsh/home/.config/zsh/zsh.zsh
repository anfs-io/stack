# zsh.zsh

# vim keybindings
bindkey -v

# use bat as pager for commands such as git diff
[ -x "$(command -v bat 2>/dev/null)" ] && export PAGER=bat

# Load ppm zsh command completions
[ -x "$(command -v ppm 2>/dev/null)" ] && eval "$(ppm completions zsh)"

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
  alias ff="fzf --filter"
fi


# General Aliases and helpers
alias cls="clear"
alias lsar="lsa -R"

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


# bat all (or a pattern of) the files in all (or depth -L) subdirs
bata() {
  local depth=""
  local pattern=""
  local hidden="-not -path '*/\.*'"
  local interactive=false
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -L) depth="-maxdepth $2"; shift 2 ;;
      -p|--pattern) pattern="-name '$2'"; shift 2 ;;
      -a|--all) hidden=""; shift ;;
      -i|--interactive) interactive=true; shift ;;
      *) break ;;
    esac
  done
  
  local files=$(eval "find . $depth -type f $hidden $pattern 2>/dev/null")
  
  if [[ -z "$files" ]]; then
    echo "No files found"
    return 1
  fi
  
  if $interactive; then
    echo "$files" | \
      fzf --multi \
          --preview 'bat --color=always --style=numbers --line-range=:500 {}' \
          --preview-window 'right:60%:wrap' \
          --bind 'ctrl-a:select-all' \
          --bind 'ctrl-d:deselect-all' \
          --bind 'ctrl-/:toggle-preview' | \
      xargs -r bat
  else
    echo "$files" | xargs bat
  fi
}


# invoke tree in various forms with specific hidden files
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

tsac() { _tsa_base "$XDG_CONFIG_HOME" "$@"; }
tsap() { _tsa_base "$XDG_DATA_HOME/ppm" "$@"; }


zconf() {
  local dir=$XDG_CONFIG_HOME/zsh file="aliases.zsh" ext="zsh"
  if [[ $# == 1 && "$1" == ".zshrc" ]]; then
    ext=""
  fi
  load_conf "$@"
}
