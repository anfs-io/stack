# tmux

install_linux() {
  if command -v tmux &> /dev/null; then
    return
  fi

  sudo apt install entr tmux -y
  post_install
}

install_macos() {
  # if command -v tmux &> /dev/null; then
  #   return
  # fi

  # brew install tmux
  post_install
}

post_install() {
  if [ ! -d $HOME/.local/share/tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm $HOME/.local/share/tmux/plugins/tpm
  fi

  tmux -c $HOME/.local/share/tmux/plugins/tpm/bin/install_plugins
  tmux -c $HOME/.local/share/tmux/plugins/tpm/tpm
}
