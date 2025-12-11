# builder

dependencies() {
  echo "ruby podman utm"
}

paths() {
  echo "$XDG_CONFIG_DIR/builder"
}

post_install() {
  source <(mise activate zsh)
  gem install webrick
}
