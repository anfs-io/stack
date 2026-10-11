# rust

# rust itself is declared in .config/mise and installed by ppm before this runs
post_install() {
  source <(mise activate bash)
  rustup component add rust-analyzer
}
