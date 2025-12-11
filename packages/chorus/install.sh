# chorus

dependencies() {
  echo "ruby"
}

paths() {
  echo "
    $XDG_CONFIG_DIR/chorus/bases.d
    $XDG_CONFIG_DIR/chorus/repos.d
    $XDG_CONFIG_DIR/chorus/spaces.d
    $XDG_HOME/.claude/commands/chorus
  "
}
