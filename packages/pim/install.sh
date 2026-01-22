# pim - Product Image Manager

dependencies() {
  echo "ruby"
}

post_install() {
  source <(mise activate zsh)
  gem install webrick thor
}
