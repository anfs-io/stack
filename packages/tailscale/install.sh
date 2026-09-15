# pde/tailscale

install_linux() {
  if ! systemctl is-active --quiet tailscaled; then
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
}

install_macos() {
  # echo "Notice: Tailscale requires sudo access"
  # sudo -v
  install_dep --cask tailscale-app
}
