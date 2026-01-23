# nvim

install_linux() {
  command -v nvim &> /dev/null && return

  local install_path="${BIN_DIR}/nvim"

  # Check for FUSE (required for AppImages)
  if ! ldconfig -p | grep -q libfuse.so.2; then
    echo "FUSE2 is not installed. Installing libfuse2..."
    install_dep libfuse2 fuse3
  fi

  install_dep build-essential ripgrep
  # if ! command -v gcc &> /dev/null; then
  #   install_dep gcc
  # fi

  # nvim release arch
  local nvim_arch="x86_64"
  if [[ "$(arch)" == "arm64" ]]; then
    nvim_arch="arm64"
  fi

  # Neovim version - using 'stable' to always get the latest stable release
  # NOTE: The latest (0.11.5) nvim 64 bit appimage download is actually 32 bit so pin the version to 0.11.4 for now
  # local nvim_version="stable"
  local nvim_version="v0.11.4"
  local download_url="https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim-linux-${nvim_arch}.appimage"

  curl -L -o "$install_path" "$download_url"
  chmod +x "$install_path" # Make it executable
  echo "Neovim (${nvim_version}) arch (${nvim_arch}) installed successfully to ${install_path}"
  echo "From ${download_url}"
  "$install_path" --version | head -n 1 # Test the installation
}

install_macos() {
  install_dep neovim ripgrep
}

post_install() {
  if [[ "$(os)" == "linux" ]]; then
    # Use the absolute path b/c PATH is not yet configured
    $BIN_DIR/nvim --headless "+Lazy! sync" +qa
  elif [[ "$(os)" == "macos" ]]; then
    /opt/homebrew/bin/nvim --headless "+Lazy! sync" +qa
  fi
}
