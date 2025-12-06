# claude

# dependencies
# mise

pre_install() {
  mkdir -p $HOME/.claude/commands
}

install_linux() { return; }

install_macos() { return; }

post_install() {
  mise install node claude
}

remove_linux() { return; }

remove_macos() { return; }
