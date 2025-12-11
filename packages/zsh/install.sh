# zsh

pre_install() {
  mkdir -p $XDG_CONFIG_DIR/zsh
}

install_linux() {
  install_dep "bat" "fzf" "tree" "zsh"
  local user=$(whoami)
  sudo usermod -s /bin/zsh $user
}

install_macos() {
  install_dep "bat" "fzf" "tree"
}

post_install() {
  local omz_dir=$XDG_LOCAL_SHARE_DIR/omz
  if [ ! -d "$omz_dir" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git $omz_dir
  fi
  if [ ! -d $omz_dir/custom/plugins/zsh-history-substring-search ]; then
    git clone https://github.com/zsh-users/zsh-history-substring-search.git $omz_dir/custom/plugins/zsh-history-substring-search
  fi
  if [ ! -d $omz_dir/custom/themes/powerlevel10k ]; then
    git clone https://github.com/romkatv/powerlevel10k.git $omz_dir/custom/themes/powerlevel10k
  fi
  mkdir -p $omz_dir/custom/functions
}

post_remove() {
  local omz_dir=$XDG_LOCAL_SHARE_DIR/omz
  rm -rf $omz_dir
}
