# mise

install_linux() {
  if command -v mise &> /dev/null; then
    return
  fi

  sudo apt install cosign curl gpg -y
  sudo install -dm 755 /etc/apt/keyrings
  wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(arch)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
  sudo apt update

  sudo apt install mise -y
  post_install
}

install_macos() {
  if command -v mise &> /dev/null; then
    return
  fi

  brew install cosign gpg mise
  post_install
}

post_install() {
  mkdir -p $CONFIG_DIR/mise/conf.d

  mise install node claude
}
