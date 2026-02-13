# solana

dependencies() {
  echo "rust node"
}

install_linux() {
  if [[ "$(arch)" == "arm64" ]]; then
    echo "There are no pre-built binaries for (arm64 Linux)"
    echo "valid targets are: x86_64-unknown-linux-gnu, x86_64-apple-darwin and aarch64-apple-darwin"
    echo "Building from source via cargo is the way to go for any arm64 Linux environment"
    exit 1
  fi
}

# From https://solana.com/docs/intro/installation/dependencies
post_install() {
  source <(mise activate bash)

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
  rm -rf "$HOME/.local/share/solana"
  rm -rf "$HOME/.cache/solana"

  # Anchor/AVM
  cargo uninstall avm 2>/dev/null || true
  rm -rf "$HOME/.avm"

  # Surfpool
  rm -f "$HOME/.local/bin/surfpool"

  if $force; then
    rm -rf $HOME/.config/solana
  else
    echo "Note: Your Solana wallet config is preserved at: $HOME/.config/solana"
    echo "To completely remove (including wallet keys):"
    echo "  ppm remove -f solana"
  fi
}
