# claude
#
# Installs Claude Code (mise). The plugin marketplaces' clones are x_install's, which ppm does not
# run (off). It also puts anfs's coordinator hooks and status line into the person's
# ~/.claude/settings.json (agents/06: post_install's settings install merges ours and keeps
# everything else; the adapter is ~/.local/lib/claude/anfs/hook), and its removal takes them out.
# Both run this package's settings, not ~/.local/lib's: post_remove runs after the unstow.

_claude_settings() { "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/home/.local/lib/claude/anfs/settings" "$@"; }

PLUGINS_DIR="$XDG_CACHE_HOME/claude/plugins"

REPOS=(
  "git@github.com:rjayroach/marketplace.git"
  "git@github.com:cnfs-io/marketplace.git"
  "git@github.com:anfs-io/marketplace.git"
)

# claude itself is declared in .config/mise and installed by ppm

x_install() {
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

post_install() {
  _claude_settings install || ppm_fail "stack/claude could not write its Claude Code hooks (above): fix that, then ppm install stack/claude" || true
}

post_remove() {
  _claude_settings remove || true
  rm -rf "$PLUGINS_DIR"
}
