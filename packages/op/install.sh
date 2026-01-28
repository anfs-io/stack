# op

dependencies() {
  echo "mise ruby"
}

post_install() {
  source <(mise activate bash)
  mise install op
  
  # Install dry-cli for opcreds
  install_gem dry-cli
}
