# claude

dependencies() {
  echo "mise"
}

paths() {
  echo "$HOME/.claude/commands"
}

post_install() {
  source <(mise activate zsh)
  mise install node claude
}
