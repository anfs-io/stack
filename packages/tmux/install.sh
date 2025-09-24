# tmux

configure() {
  tmux -c $HOME/.local/share/tmux/plugins/tpm/bin/install_plugins
  tmux -c $HOME/.local/share/tmux/plugins/tpm/tpm
}

install_linux() {
  sudo apt install entr tmux -y

  if [ ! -d $HOME/.local/share/tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm $HOME/.local/share/tmux/plugins/tpm
  fi
  configure
}
