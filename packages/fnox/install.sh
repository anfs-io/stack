# fnox

post_install() {
  source <(mise activate bash)
  mise install fnox
  install_completion "fnox completion zsh"
}
