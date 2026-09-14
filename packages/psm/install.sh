#!/usr/bin/env bash

post_install() {
  local psm_config="${XDG_CONFIG_HOME:-$HOME/.config}/psm"
  local psm_data="${XDG_DATA_HOME:-$HOME/.local/share}/psm"

  # Create PSM config directory
  mkdir -p "$psm_config/services"

  # Create PSM data directory
  mkdir -p "$psm_data/volumes"

  install_completion "psm completion zsh"
}

# Refuse removal while compose containers are running (override with ppm remove -f)
pre_remove() {
  command -v podman &>/dev/null || return 0
  local running
  running=$(podman ps --filter label=com.docker.compose.project --format '{{.Names}}' 2>/dev/null) || return 0
  [[ -z "$running" ]] && return 0
  echo "psm has running containers:"
  printf '  %s\n' $running
  echo "Stop them first (psm down <service>) or pass -f to remove anyway."
  return 1
}
