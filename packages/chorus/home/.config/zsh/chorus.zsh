# chorus

_chorus_cd() {
   local cmd=$1 name=$2
   local target="$($cmd ls --path "$name" 2>/dev/null)"

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

alias hls="hub list"
alias mx="tmuxinator"
alias rcl="repo clone"
alias rls="repo list"
