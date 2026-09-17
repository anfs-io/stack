# ruby

# The default gems file must exist before mise installs ruby, which ppm does after the hooks
post_install() {
  source <(mise activate bash)
  add_to_file "$MISE_RUBY_DEFAULT_PACKAGES_FILE" bundler rbs ruby-lsp
}
