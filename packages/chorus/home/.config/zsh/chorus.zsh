# chorus

export CHORUS_PATH="$HOME/spaces:$HOME/spikes"
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

chorus_spaces > $XDG_CACHE_HOME/chorus/spaces


chorus_repos() {
  local -a repos=()
  for space in $(chorus_spaces); do
    while IFS= read -r gitdir; do
      repos+=("${gitdir:h}")
    done < <(find -L "$space" -name .git -type d 2>/dev/null)
  done
  print -l "${repos[@]}"
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
