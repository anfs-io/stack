# coder

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/coder
}

install_linux() { return; }

install_macos() {
  brew bundle --file=$XDG_CONFIG_DIR/coder/Brewfile
}

post_install() { return; }
