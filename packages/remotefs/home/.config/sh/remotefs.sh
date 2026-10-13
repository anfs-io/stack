# remotefs.sh — portable (bash and zsh); completion is in .config/{zsh,bash}/remotefs.*

# Wrapper to handle `remotefs cd` since subshells can't change parent directory. With a label it
# mounts what is not mounted yet, so `remotefs cd web1` is all it takes to be there.
remotefs() {
  if [[ "${1:-}" == "cd" ]]; then
    shift
    local dir
    if [[ $# -eq 0 ]]; then
      dir=$(command remotefs path) || return $?
    else
      command remotefs mount "$1" >/dev/null || return $?
      dir=$(command remotefs path "$1") || return $?
    fi
    builtin cd "$dir"
  else
    command remotefs "$@"
  fi
}
