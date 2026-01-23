# tmuxinator

dependencies() {
  echo "tmux chorus"
}

post_install() {
  source <(mise activate bash)
  gem install tmuxinator
}
