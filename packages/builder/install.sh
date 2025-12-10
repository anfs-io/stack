# builder

dependencies() {
  echo "ruby podman utm"
}

pre_install() { return; }

install_linux() { return; }

install_macos() { return; }

post_install() {
  source <(mise activate zsh)
  gem install webrick
}
