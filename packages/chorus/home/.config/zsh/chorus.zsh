# chorus

_chorus_cd() {
   local cmd=$1 name=$2
   local target
   target=$($cmd ls --path "$name" 2>/dev/null)
   if [[ -n "$target" ]]; then
     cd "$target"
   else
     echo "'$name' not found in $cmd" >&2
     return 1
   fi
}

hcd() { _chorus_cd hub "$1" }

hconf() {
  local dir=$CONFIG_DIR/chorus file="hubs" ext="yml"
  load_conf $1 $2
}

rcd() { _chorus_cd repo "$1" }

rconf() {
  local dir=$CONFIG_DIR/chorus/repos.d file="." ext="yml"
  load_conf $1 $2
}

alias hls="hub list"
alias mx="tmuxinator"
alias rcl="repo clone"
alias rls="repo list"
