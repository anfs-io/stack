# psm.zsh — Podman Service Manager shell function
# Sets PSM-specific env vars and delegates to the ppm engine

export PSM_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/psm"
export PSM_SERVICES_HOME="$PSM_CONFIG_HOME/services"

export PSM_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/psm"
export PSM_VOLUMES_HOME="$PSM_DATA_HOME/volumes"

export PSM_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/psm"

sconf() {
  local dir=$PSM_SERVICES_HOME file="../registry.yml" ext="compose.yml"
  load_conf "$@"
}

# Wrapper to handle `psm cd` since subshells can't change parent directory
psm() {
  if [[ "${1:-}" == "cd" ]]; then
    shift
    if [[ $# -eq 0 ]]; then
      builtin cd "$PSM_SERVICES_HOME"
    else
      local service_path
      service_path=$(command psm path "$@") || return $?
      builtin cd "$service_path"
    fi
  else
    command psm "$@"
  fi
}

# --- podman / podman-compose --psm integration ------------------------------
# Plain podman commands pass straight through. Add `--psm` anywhere to a compose
# command and it is handed to `psm` to resolve psm-provided services:
#
#   podman compose up postgres          # stock podman, cwd compose file
#   podman compose up --psm postgres    # psm-provided postgres (same as `psm up postgres`)
#   podman compose --psm logs -f postgres glitchtip

podman() {
  if (( ${argv[(Ie)--psm]} )); then
    local -a args=("${(@)argv:#--psm}")
    if [[ "${args[1]}" == "compose" ]]; then
      PSM_COMPOSE="podman compose" command psm __compose "${(@)args[2,-1]}"
      return $?
    fi
    echo "psm: --psm only applies to 'podman compose'; ignoring it" >&2
    command podman "${args[@]}"
    return $?
  fi

  command podman "$@"
}

podman-compose() {
  if (( ${argv[(Ie)--psm]} )); then
    PSM_COMPOSE="podman-compose" command psm __compose "${(@)argv:#--psm}"
    return $?
  fi

  command podman-compose "$@"
}
