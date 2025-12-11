# builder

dependencies() {
  echo "ruby podman utm"
}

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/builder
}

post_install() {
  source <(mise activate zsh)
  gem install webrick
}
