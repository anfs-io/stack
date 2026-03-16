# claude

PLUGINS_DIR="$XDG_CACHE_HOME/claude/plugins"

REPOS=(
  "git@github.com:rjayroach/marketplace.git"
  "git@github.com:cnfs-io/marketplace.git"
  "git@github.com:anfs-io/marketplace.git"
)

post_install() {
  source <(mise activate bash)
  mise install claude

  mkdir -p "$PLUGINS_DIR"

  for url in "${REPOS[@]}"; do
    local owner="${url#*:}"
    owner="${owner%%/*}"
    local target="$PLUGINS_DIR/$owner"

    if [[ -d "$target/.git" ]]; then
      user_message "Pulled $owner into $target"
      git -C "$target" pull --quiet
    else
      user_message "Cloned $owner into $target"
      git clone --quiet "$url" "$target"
    fi
  done
}

post_remove() {
  rm -rf "$PLUGINS_DIR"
}
