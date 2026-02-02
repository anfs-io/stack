# ruby

dependencies() {
  echo "mise"
}

install_linux() {
  command -v ruby &> /dev/null && command -v mise &> /dev/null && return

  install_dep build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
    libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev
}

install_macos() {
  install_dep libyaml openssl readline pkgconf
}

post_install() {
  source <(mise activate bash)
  add_to_file "$MISE_RUBY_DEFAULT_PACKAGES_FILE" bundler rbs ruby-lsp
  mise install ruby
}
