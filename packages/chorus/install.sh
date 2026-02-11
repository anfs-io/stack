# chorus

dependencies() {
  echo "ruby gems"
}

post_install() {
  source <(mise activate bash)
  install_gem tmuxinator
}
