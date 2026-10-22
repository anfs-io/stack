# ruby helpers for ppm

# install_gem <gem>...: add the gems to mise's default gems ($MISE_RUBY_DEFAULT_PACKAGES_FILE,
# ~/.local/share/ruby/default-gems: ruby.toml), so every ruby mise installs gets them, and install
# each into the current ruby now
install_gem() {
  add_to_file "$MISE_RUBY_DEFAULT_PACKAGES_FILE" "$@"
  sort -o "$MISE_RUBY_DEFAULT_PACKAGES_FILE" "$MISE_RUBY_DEFAULT_PACKAGES_FILE"

  for gem in "$@"; do
    if ! gem list -i "^${gem}$" &>/dev/null; then
      gem install "$gem"
    fi
  done
}
