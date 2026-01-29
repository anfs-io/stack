# zsh

install_linux() {
  install_dep bat fzf htop tree zsh
  local user=$(whoami)
  sudo usermod -s /bin/zsh $user
}

install_macos() {
  install_dep bat fzf htop tree
}

post_install() {
  local omz_dir=$XDG_DATA_HOME/omz
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
  rm -rf $XDG_DATA_HOME/omz $XDG_CACHE_HOME/p10k-*
}
