# ruby

install_linux() {
  if command -v ruby &> /dev/null; then
    return
  fi

  sudo apt install build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
    libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev git -y
  post_install
}

install_macos() {
  if command -v ruby &> /dev/null; then
    return
  fi

  brew install libyaml openssl readline
  post_install
}

post_install() {
  install_packages mise
  mise install ruby
}
