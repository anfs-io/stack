# ppm.zsh

if ! command -v ppm >/dev/null 2>&1; then
  return
fi

# Load ppm zsh command completions
eval "$(ppm completions zsh)"

# Wrapper to handle `ppm cd` since subshells can't change parent directory
ppm() {
  if [[ "${1:-}" == "cd" ]]; then
    shift
    local verbose_flag=""
    [[ "${1:-}" == "-v" ]] && { verbose_flag="-v"; shift; }
    local pkg_path
    pkg_path=$(command ppm path $verbose_flag "$@") || return $?
    cd "$pkg_path"
  else
    command ppm "$@"
  fi
}
