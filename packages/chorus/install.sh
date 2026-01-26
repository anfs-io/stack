# chorus

dependencies() {
  echo "ruby"
}

post_install() {
  source <(mise activate bash)
  install_gem git thor tmuxinator
}
