# mise

dependencies() {
  echo "zsh"
}

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/mise/conf.d
}

install_linux() {
  command -v mise &> /dev/null && return

  # sudo apt install cosign curl gpg -y
  install_dep cosign curl gpg -y

  sudo install -dm 755 /etc/apt/keyrings
  wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(arch)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
  sudo apt update

  # sudo apt install mise -y
  install_dep mise
}

install_macos() {
  # command -v mise &> /dev/null && return
  install_dep cosign gpg mise
}

post_install() { return; }
