# op

install_macos() {
  install_dep --cask 1password
}

post_install() {
  source <(mise activate bash)
  mise install op
}
