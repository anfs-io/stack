# op

dependencies() {
  echo "mise"
}

paths() {
  echo "$XDG_CONFIG_DIR/op"
}

post_install() {
  source <(mise activate zsh)
  mise install op
}
