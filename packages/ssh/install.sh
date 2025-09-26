# ssh

pre_install() {
  [[ ! -d $HOME/.ssh/config.d ]] && mkdir -p $HOME/.ssh/config.d
}

install_linux() { return; }

install_macos() {
  [[ ! coder_local ]] && return

  if ! command -v lazyssh &>/dev/null; then
    brew install lazyssh
  fi
}

post_install() { return; }
