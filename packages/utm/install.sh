# utm

pre_install() { return; }
install_linux() { return; }

install_macos() {
  brew install utm
  if [[ ! -f $HOME/.local/bin/utmctl ]]; then
    ln -s /Applications/UTM.app/Contents/MacOS/utmctl $HOME/.local/bin
  fi
}

post_install() { return; }
