# utm

dependencies() { echo ""; }

pre_install() { return; }

install_linux() { return; }

install_macos() {
  install_dep utm

  if [[ ! -f $XDG_BIN_DIR/utmctl ]]; then
    ln -s /Applications/UTM.app/Contents/MacOS/utmctl $XDG_BIN_DIR
  fi
}

post_install() { return; }
