# utm

install_macos() {
  install_dep utm

  if [[ ! -f $XDG_BIN_DIR/utmctl ]]; then
    ln -s /Applications/UTM.app/Contents/MacOS/utmctl $XDG_BIN_DIR
  fi
}
