# fnox

post_install() {
  mise install fnox
  source <(mise activate bash)
  install_completion "fnox completion zsh"
}
