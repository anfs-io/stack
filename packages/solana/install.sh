# solana

install_linux() {
  if [[ "$(arch)" == "arm64" ]]; then
    ppm_fail "No pre-built binaries for arm64 Linux.\nValid targets: x86_64-unknown-linux-gnu, x86_64-apple-darwin, aarch64-apple-darwin.\nBuild from source via cargo instead."
    return
  fi
}

# From https://solana.com/docs/intro/installation/dependencies
post_install() {
  source <(mise activate bash)
  install_completion "solana completion -s zsh"

  # Solana CLI
  sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"

  # Anchor
  cargo install --git https://github.com/coral-xyz/anchor avm --force
  avm install latest
  avm use latest

  # Update the Solana CLI to the latest version, as needed (Optional)
  # agave-install update

  # surfpool
  curl -sL https://run.surfpool.run/ | bash
}

post_remove() {
  # Solana CLI (installed via Anza installer)
  rm -rf "$XDG_DATA_HOME/solana"
  rm -rf "$XDG_CACHE_HOME/solana"

  # Anchor/AVM
  cargo uninstall avm 2>/dev/null || true
  rm -rf "$HOME/.avm"

  # Surfpool
  rm -f "$BIN_DIR/surfpool"

  if $force; then
    rm -rf $XDG_CONFIG_HOME/solana
  else
    user_message "Note: Your Solana wallet config is preserved at: $XDG_CONFIG_HOME/solana\n" \
      "To completely remove (including wallet keys):\n" \
      "  ppm remove -f solana"
  fi
}
