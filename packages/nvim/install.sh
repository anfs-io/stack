# nvim

post_install() {
  nvim --headless "+Lazy! sync" +qa
}
