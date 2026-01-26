# ruby-tools

dependencies() {
  echo "ruby"
}

post_install() {
  source <(mise activate bash)
  install_gem amazing_print git guard pry pry-doc rspec rubocop rubocop-rspec ruby-lsp-rspec
}
