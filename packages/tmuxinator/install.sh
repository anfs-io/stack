# tmuxinator

dependencies() {
  echo "ruby tmux"
}

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/tmuxinator
}

install_linux() { return; }

install_macos() { return; }

post_install() {
  if command -v gem &> /dev/null; then
    if ! command -v tmuxinator &> /dev/null; then
      gem install tmuxinator
    fi
  fi
}
