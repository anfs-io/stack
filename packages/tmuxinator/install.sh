# tmuxinator

dependencies() {
  echo "tmux chorus"
}

post_install() {
  source <(mise activate zsh)
  gem install tmuxinator
}
