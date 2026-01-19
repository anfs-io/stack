# claude

# dependencies() {
#   echo "node"
# }

post_install() {
  source <(mise activate zsh)
  mise install claude
}
