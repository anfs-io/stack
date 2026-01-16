# utm

install_macos() {
  install_dep utm

  if [[ ! -f $BIN_DIR/utmctl ]]; then
    ln -s /Applications/UTM.app/Contents/MacOS/utmctl $BIN_DIR
  fi
}
