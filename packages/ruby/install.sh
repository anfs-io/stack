# ruby

# The default gems file must exist before mise installs ruby, which ppm does after the hooks
post_install() {
  source <(mise activate bash)
  add_to_file "$MISE_RUBY_DEFAULT_PACKAGES_FILE" bundler rbs ruby-lsp
}

# ported from ruby-tools
# not sure if want to implement this
x_post_install() {
  source <(mise activate bash)
  install_gem amazing_print git guard pry pry-doc rspec rubocop rubocop-rspec ruby-lsp-rspec
}
