# pde/tailscale
#
# Linux keeps the vendor installer: it adds Tailscale's own repo and sets up the tailscaled
# systemd service, which a declared package cannot do
install_linux() {
  if ! systemctl is-active --quiet tailscaled; then
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
}
