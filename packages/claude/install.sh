# claude
#
# Installs Claude Code (mise). It also puts anfs's coordinator hooks and status line into the
# person's ~/.claude/settings.json (agents/06: post_install's settings install merges ours and
# keeps everything else; the adapter is ~/.local/lib/claude/anfs/hook), and its removal takes them
# out.
# Both run this package's settings, not ~/.local/lib's: post_remove runs after the unstow.

_claude_settings() { "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/home/.local/lib/claude/anfs/settings" "$@"; }

# claude itself is declared in .config/mise and installed by ppm

post_install() {
  _claude_settings install || ppm_fail "stack/claude could not write its Claude Code hooks (above): fix that, then ppm install stack/claude" || true
}

post_remove() {
  _claude_settings remove || true
}
