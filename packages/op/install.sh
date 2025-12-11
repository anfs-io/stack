# op

dependencies() {
  echo "mise"
}

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/op
}

post_install() {
  source <(mise activate zsh)
  # mise install op
}
