# ruby

install_packages mise

install_linux() {
  sudo apt install build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
    libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev git -y
  post_install
}

install_macos() {
  post_install
}

post_install() {
  mise install ruby
}
