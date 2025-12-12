# solana

dependencies() {
  echo "rust"
}

post_install() {
  curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash
}

