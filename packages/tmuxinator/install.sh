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
  source <(mise activate zsh)
  gem install tmuxinator
}
