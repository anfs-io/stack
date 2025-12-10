# chorus

dependencies() {
  echo "ruby"
}

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/chorus/bases.d
  mkdir -p $XDG_CONFIG_DIR/chorus/repos.d
  mkdir -p $XDG_CONFIG_DIR/chorus/spaces.d
}

install_linux() { return; }

install_macos() { return; }

post_install() { return; }
