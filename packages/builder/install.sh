# builder

pre_install() { return; }

install_linux() {
  sudo apt install --yes podman podman-compose
}

install_macos() {
  brew install podman podman-compose

  if ! podman machine list --format "{{.Name}}" | grep -q "podman-machine-default"; then
    podman machine init
  fi

  if ! podman machine list --format "{{.Running}}" | grep -q "true"; then
    podman machine start
  fi
}

post_install() {
  gem install webrick
}
