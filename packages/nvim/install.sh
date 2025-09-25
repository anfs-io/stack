# nvim

mkdir -p $CONFIG_DIR/nvim

install_linux() {
  local install_path="${HOME}/.local/bin/nvim"

  if [ -f $install_path ]; then
    return
  fi

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

  # Create ~/.local/bin if it doesn't exist
  mkdir -p $HOME/.local/bin
  curl -L -o "$install_path" "$download_url"
  chmod +x "$install_path" # Make it executable
  echo "Neovim (${nvim_version}) installed successfully to ${install_path}"
  "$install_path" --version | head -n 1 # Test the installation

  # Now configure it
  configure
  post_install
}

install_macos() {
  if ! command -v nvim &> /dev/null; then
    brew install neovim
  fi
  post_install
}

post_install() {
  # Use the absolute path b/c PATH is not yet configured
  $HOME/.local/bin/nvim --headless "+Lazy! sync" +qa
}
