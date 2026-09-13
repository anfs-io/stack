# psm.zsh — Podman Service Manager shell function
# Sets PSM-specific env vars and delegates to the ppm engine

export PSM_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/psm"
export PSM_SERVICES_HOME="$PSM_CONFIG_HOME/services"

export PSM_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/psm"
export PSM_VOLUMES_HOME="$PSM_DATA_HOME/volumes"

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

# Resolve compose -f flags for a service into $reply
_podman_resolve_compose_flags() {
  local service="$1"
  local service_dir="${PSM_SERVICES_HOME}/${service}"
  local compose_file="${service_dir}/compose.yml"
  local manifest="${PSM_CONFIG_HOME}/registry.yml"
  local net_file="${PSM_CONFIG_HOME}/compose/network.yml"

  reply=()
  if [[ ! -f "$compose_file" ]]; then
    echo "Error: Service compose file not found at $compose_file" >&2
    return 1
  fi

  # Store base service compose file
  reply=("-f" "$compose_file")

  # Check if service is listed in network_attached_services
  if [[ -f "$manifest" ]] && yq eval ".network_attached_services[] | select(. == \"$service\")" "$manifest" 2>/dev/null | grep -qx "$service"; then
    local network=$(yq eval '.shared_network // "dev-net"' "$manifest")
    command podman network exists "$network" 2>/dev/null || command podman network create "$network" >/dev/null

    # Dynamically extract the root service name inside the file
    local service_key=$(yq eval '.services | keys | .[0]' "$service_file")

    # Write the override to a real file: compose providers run as separate
    # processes and can't read a <(...) /dev/fd path from this shell
    local override="${XDG_CACHE_HOME:-$HOME/.cache}/psm/${service}.network.yml"
    mkdir -p "${override:h}"
    cat > "$override" <<EOF
services:
  ${service_key}:
    networks:
      - ${network}
EOF

    # Append network definitions
    reply+=("-f" "$net_file" "-f" "$override")
  fi
}

# Run `up`/`down [service]` through a compose runner ("podman compose" or "podman-compose")
_psm_compose() {
  local runner="$1" subcmd="$2"
  shift 2

  # Parse flags vs target service name
  local service=""
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*) extra_args+=("$1"); shift ;;
      *) service="$1"; shift ;;
    esac
  done

  # No service given: plain passthrough
  if [[ -z "$service" ]]; then
    command ${=runner} "$subcmd" "${extra_args[@]}"
    return $?
  fi

  local -a reply
  _podman_resolve_compose_flags "$service" || return 1
  local -a flags=("${reply[@]}")

  if [[ "$subcmd" == "up" ]]; then
    # Default to detached mode if -d not explicitly passed
    [[ " ${extra_args[*]} " =~ " -d " ]] || extra_args+=("-d")
  fi

  command ${=runner} "${flags[@]}" "$subcmd" "${extra_args[@]}"
  # echo "$runner" "${flags[@]}" "$subcmd" "${extra_args[@]}"
  return $?
}

podman() {
  # Intercept 'podman compose up' or 'podman compose down'
  if [[ "$1" == "compose" ]] && [[ "$2" == "up" || "$2" == "down" ]]; then
    _psm_compose "podman compose" "${@:2}"
    return $?
  fi

  # Fall through to standard podman binary for all other invocations
  command podman "$@"
}

podman-compose() {
  # Intercept 'podman-compose up' or 'podman-compose down'
  if [[ "$1" == "up" || "$1" == "down" ]]; then
    _psm_compose "podman-compose" "$@"
    return $?
  fi

  command podman-compose "$@"
}
