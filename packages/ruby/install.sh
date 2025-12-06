# ruby
# dependencies: mise

pre_install() { return; }

install_linux() {
  command -v ruby &> /dev/null && return

  sudo apt install build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
    libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev git -y
}

install_macos() {
  install_dep libyaml openssl readline
}

post_install() {
  # install mise
  mise install ruby
}
