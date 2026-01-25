# podman

install_linux() {
  install_dep podman podman-compose
}

install_macos() {
  install_dep podman podman-compose

  if ! podman machine list --format "{{.Name}}" | grep -q "podman-machine-default"; then
    podman machine init
  fi

  if ! podman machine list --format "{{.Running}}" | grep -q "true"; then
    podman machine start
  fi

  # You need it for tools that expect the Docker socket at the standard location - like LocalStack, docker-compose, or other tools that don't read $DOCKER_HOST reliably.
  # If podman ps works and LocalStack also works with your current $DOCKER_HOST setup, you might not need the helper at all.
  # if [[ ! -S /var/run/docker.sock ]]; then
  #   sudo $HOMEBREW_PREFIX/bin/podman-mac-helper install
  # fi
}
