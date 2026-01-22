# mise

# dependencies() {
#   echo "zsh"
# }

install_linux() {
  install_dep cosign curl gpg

  if ! command -v mise &> /dev/null; then
    sudo install -dm 755 /etc/apt/keyrings
    wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(arch)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
    sudo apt update
  fi

  install_dep mise
}

install_macos() {
  install_dep cosign gpg mise
}
