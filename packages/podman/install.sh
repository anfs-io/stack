# podman

install_linux() {
  install_dep podman podman-compose

  # Podman API socket for docker-compatible clients (dockge, dev containers, testcontainers)
  if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user enable --now podman.socket
  else
    user_message "No systemd user session, so the podman API socket was not enabled.\nRun 'podman system service --time=0 &' when a docker-compatible client needs it."
  fi
}

install_macos() {
  install_dep podman podman-compose

  # The podman API socket runs inside the podman machine VM; nothing to enable here.
  # Clients running in containers get its VM-side path from:
  #   podman info --format '{{.Host.RemoteSocket.Path}}'

  if ! podman machine list --format "{{.Name}}" | grep -q "podman-machine-default"; then
    podman machine init
  fi

  # if ! podman machine list --format "{{.Running}}" | grep -q "true"; then
  #   podman machine start
  # fi

  # You need it for tools that expect the Docker socket at the standard location - like LocalStack, docker-compose, or other tools that don't read $DOCKER_HOST reliably.
  # If podman ps works and LocalStack also works with your current $DOCKER_HOST setup, you might not need the helper at all.
  # if [[ ! -S /var/run/docker.sock ]]; then
  #   sudo $HOMEBREW_PREFIX/bin/podman-mac-helper install
  # fi
}

post_install() {
  install_completion "podman completion zsh"
}
