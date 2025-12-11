# builder

dependencies() {
  echo "ruby podman utm"
}

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/builder
}

install_linux() { return; }

install_macos() { return; }

post_install() {
  source <(mise activate zsh)
  gem install webrick
}
