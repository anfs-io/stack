# solana

install_linux() {
  if [[ "$(arch)" == "arm64" ]]; then
    ppm_fail "No pre-built binaries for arm64 Linux.\nValid targets: x86_64-unknown-linux-gnu, x86_64-apple-darwin, aarch64-apple-darwin.\nBuild from source via cargo instead."
    return
  fi
}

# NOTE: Not using brew for surfpool since post_install uses a cross platform installer, but here in case future want to use packagges; Linux can use `snap`
# install_macos() {
#   # From https://youtu.be/tibT9ZPb8wE?list=PL0FMgRjJMRzO1FdunpMS-aUS4GNkgyr3T&t=19
#   brew tap txtx/taps
#   install_dep surfpool
# }

# From https://solana.com/docs/intro/installation/dependencies
post_install() {
  # 1. Solana CLI
  if command -v agave-install &> /dev/null; then
    # Update the Solana CLI to the latest version
    agave-install update
  else
    sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
  fi
  install_completion "solana completion --shell zsh"

  # 2. Anchor Version Manager (avm)
  if command -v avm &> /dev/null; then
    avm self-update
  else
    cargo install --git https://github.com/coral-xyz/anchor avm --force
  fi

  # 3. Anchor Framework
  avm install latest
  avm use latest
  install_completion "anchor completions zsh"

  # 4. Surfpool local validator
  curl -sL https://run.surfpool.run/ | bash
  # Surfpool does not output to STDOUT, but rather writes a file
  surfpool completions zsh
  mv _surfpool $PPM_FPATH
}

post_remove() {
  # 1. Solana CLI (installed via Anza installer)
  rm -rf "$XDG_DATA_HOME/solana"
  rm -rf "$XDG_CACHE_HOME/solana"

  # 2. Anchor/AVM
  cargo uninstall avm 2>/dev/null || true
  rm -rf "$HOME/.avm"

  # 3. Surfpool
  rm -f "$BIN_DIR/surfpool"

  if $force; then
    rm -rf $XDG_CONFIG_HOME/solana
  else
    user_message "Note: Your Solana wallet config is preserved at: $XDG_CONFIG_HOME/solana\n" \
      "To completely remove (including wallet keys):\n" \
      "  ppm remove -f solana"
  fi
}
