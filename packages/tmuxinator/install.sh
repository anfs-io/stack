# tmuxinator

dependencies() {
  echo "tmux chorus"
}

paths() {
  echo "$XDG_CONFIG_DIR/tmuxinator"
  echo "$XDG_LOCAL_SHARE_DIR/tmuxinator"
}

post_install() {
  source <(mise activate zsh)
  gem install tmuxinator
}
