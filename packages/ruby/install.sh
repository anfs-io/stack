# ruby

dependencies() {
  echo "mise"
}

paths() {
  echo "
    $XDG_CONFIG_HOME/pry
    $XDG_CONFIG_HOME/rails/templates
    $XDG_CONFIG_HOME/rubocop
    $XDG_CONFIG_HOME/ruby
  "
}

install_linux() {
  command -v ruby &> /dev/null && return

  install_dep build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
    libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev
}

install_macos() {
  install_dep libyaml openssl readline pkgconf
}

post_install() {
  source <(mise activate bash)
  mise install ruby
}
