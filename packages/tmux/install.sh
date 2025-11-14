# tmux

pre_install() { return; }

install_linux() {
  command -v tmux &> /dev/null && return
  install_dep entr tmux
}

install_macos() {
  command -v tmux &> /dev/null && return
  install_dep tmux
}

post_install() {
  tmux_plugins_dir=$XDG_LOCAL_SHARE_DIR/tmux/plugins
  tpm_dir=$tmux_plugins_dir/tpm
  if [ ! -d $tpm_dir ]; then
    git clone https://github.com/tmux-plugins/tpm $tpm_dir
  fi

  tmux -c $tpm_dir/bin/install_plugins
  echo "Did not run 'tmux -c $tpm_dir/tpm'"
}
