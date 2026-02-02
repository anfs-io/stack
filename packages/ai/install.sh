# ai.sh

dependencies() {
  echo "node"
}

post_install() {
  source <(mise activate bash)
  mise install opencode
  mise install npm:openclaw
  mise install npm:prpm
  mise install npm:ralph-tui
}
