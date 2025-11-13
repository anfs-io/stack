# coder

pre_install() { return; }

install_linux() { return; }

install_macos() {
  brew bundle --file=$XDG_CONFIG_DIR/coder/Brewfile
}

post_install() { return; }
