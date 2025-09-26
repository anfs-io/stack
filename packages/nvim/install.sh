# nvim

pre_install() {
  [[ ! -d $CONFIG_DIR/nvim ]] && mkdir -p $CONFIG_DIR/nvim
}

install_linux() {
  command -v nvim &> /dev/null && return

  local install_path="${HOME}/.local/bin/nvim"

  # Check for FUSE (required for AppImages)
  if ! ldconfig -p | grep -q libfuse.so.2; then
    echo "FUSE2 is not installed. Installing libfuse2..."
    sudo apt-get install libfuse2 fuse3 -y
  fi

  # nvim release arch
  local nvim_arch="x86_64"
  if [[ "$(arch)" == "arm64" ]]; then
    nvim_arch="arm64"
  fi

  # Neovim version - using 'stable' to always get the latest stable release
  local nvim_version="stable"
  local download_url="https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim-linux-${nvim_arch}.appimage"

  curl -L -o "$install_path" "$download_url"
  chmod +x "$install_path" # Make it executable
  echo "Neovim (${nvim_version}) installed successfully to ${install_path}"
  "$install_path" --version | head -n 1 # Test the installation
}

install_macos() {
  command -v nvim &> /dev/null && return
  install_dep neovim
}

post_install() {
  if [[ "$(os)" == "linux" ]]; then
    # Use the absolute path b/c PATH is not yet configured
    $BIN_DIR/nvim --headless "+Lazy! sync" +qa
  elif [[ "$(os)" == "macos" ]]; then
    /opt/homebrew/bin/nvim --headless "+Lazy! sync" +qa
  fi
}
