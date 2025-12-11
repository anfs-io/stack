# op

dependencies() {
  echo "mise"
}

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/op
}

install_linux() { return; }

install_macos() { return; }

post_install() {
  source <(mise activate zsh)
  # mise install op
}
