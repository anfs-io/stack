# solana

dependencies() {
  echo "rust node"
}

x_post_install() {
  source <(mise activate bash)
  curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash
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

