# op

dependencies() {
  echo "ruby"
}

post_install() {
  install_dep --cask 1password
  source <(mise activate bash)
  mise install op
  
  # Install dry-cli for opcred
  install_gem dry-cli
}
