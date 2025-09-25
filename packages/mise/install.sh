# mise

mkdir -p $CONFIG_DIR/mise/conf.d

# configure_mise() {
#   eval "$(mise activate zsh)" && mise install
# }

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
  mise install
  # configure_mise
}

install_macos() {
  if command -v mise &> /dev/null; then
    return
  fi
  brew install mise
}
