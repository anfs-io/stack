#!/usr/bin/env bash

post_install() {
  local psm_config="${XDG_CONFIG_HOME:-$HOME/.config}/psm"
  local psm_data="${XDG_DATA_HOME:-$HOME/.local/share}/psm"

  # Create PSM config directory
  mkdir -p "$psm_config/services"

  # Create PSM data directory
  mkdir -p "$psm_data/volumes"

  install_completion "psm completions zsh"
}
