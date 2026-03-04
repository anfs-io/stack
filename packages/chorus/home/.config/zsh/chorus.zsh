# chorus

# export CHORUS_PATH="$HOME/spaces:$HOME/spikes"
export CHORUS_PATH="$HOME/spaces"
export CHORUS_DEBUG_PATH="$XDG_CACHE_HOME/chorus/debug"

chorus_spaces() {
  local IFS=':'
  for base in $=CHORUS_PATH; do
    [[ -d "$base" ]] || continue
    for dir in "$base"/*(N/); do
      print -l "$dir"
    done
  done
}

# chorus_spaces > $XDG_CACHE_HOME/chorus/spaces


chorus_repos() {
  local -a repos=()
  local in_space=false
  local sync_gitignore=false
  [[ "$1" == "-g" ]] && sync_gitignore=true

  for space in $(chorus_spaces); do
    if [[ "$PWD" == "$space"* ]]; then
      in_space=true
      while IFS= read -r gitdir; do
        [[ "${gitdir:h}" == "$PWD" ]] && continue
        repos+=("${${gitdir:h}#$PWD/}")
      done < <(find -L "$PWD" -name .git -type d 2>/dev/null)
      break
    fi
  done

  if ! $in_space; then
    if $sync_gitignore; then
      echo "-g is only applicable inside a space" >&2
      return 1
    fi
    for space in $(chorus_spaces); do
      while IFS= read -r gitdir; do
        repos+=("${gitdir:h}")
      done < <(find -L "$space" -name .git -type d 2>/dev/null)
    done
  fi

  if $in_space && $sync_gitignore && [[ -d "$PWD/.git" ]]; then
    local gitignore="$PWD/.gitignore"
    local existing=""
    [[ -f "$gitignore" ]] && existing=$(<"$gitignore")
    for repo in "${repos[@]}"; do
      local entry="$repo/"
      if ! grep -qxF "$entry" <<< "$existing" 2>/dev/null; then
        print "$entry" >> "$gitignore"
        existing+=$'\n'"$entry"
      fi
    done
  fi

  $sync_gitignore || print -l "${repos[@]}"
}

_chorus_cd() {
   local cmd=$1 name=$2
   local target="$(chorus $cmd show "$name" full_path 2>/dev/null)"

   if [[ -n "$target" ]]; then
     cd "$target"
   else
     echo "'$name' not found in $cmd" >&2
     return 1
   fi
}

hcd() { _chorus_cd hub "$1" }

hconf() {
  local dir=$XDG_CONFIG_HOME/chorus/hubs.d file="../hubs.yml" ext="yml"
  mkdir -p $dir
  load_conf "$@"
}

rcd() { _chorus_cd repo "$1" }

rconf() {
  local dir=$XDG_CONFIG_HOME/chorus/repos.d file="../repos.yml" ext="yml"
  mkdir -p $dir
  load_conf "$@"
}

alias hls="chorus hub list"
alias mx="tmuxinator"
alias rcl="chorus repo clone"
alias rls="chorus repo list"
