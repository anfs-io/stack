# ssh

pre_install() {
  mkdir -p $HOME/.ssh/config.d
}

install_linux() { return; }

install_macos() {
  if ! command -v lazyssh &>/dev/null; then
    brew install lazyssh
  fi
}

post_install() { return; }
