# op

dependencies() {
  echo "mise"
}

paths() {
  echo "$XDG_CONFIG_HOME/op"
}

post_install() {
  source <(mise activate zsh)
  mise install op
}
