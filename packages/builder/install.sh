# builder

pre_install() { return; }

install_linux() {
  sudo apt install --yes podman

  gem install webrick
}

install_macos() {
  brew install podman podman-compose

  gem install webrick
}

post_install() {
  if ! podman machine list --format "{{.Name}}" | grep -q "podman-machine-default"; then
    podman machine init
  fi

  if ! podman machine list --format "{{.Running}}" | grep -q "true"; then
    podman machine start
  fi
}
