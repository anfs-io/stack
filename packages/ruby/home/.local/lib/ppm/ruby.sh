# ruby helpers for ppm

install_gem() {
  add_to_file "$MISE_RUBY_DEFAULT_PACKAGES_FILE" "$@"
  sort -o "$MISE_RUBY_DEFAULT_PACKAGES_FILE" "$MISE_RUBY_DEFAULT_PACKAGES_FILE"

  for gem in "$@"; do
    if ! gem list -i "^${gem}$" &>/dev/null; then
      gem install "$gem"
    fi
  done
}
