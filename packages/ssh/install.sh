# ssh

install_linux() {
  install_dep sshfs
}

# macFUSE (formerly OSXFUSE) is a framework that allows mounting user-space filesystems on macOS
# It provides the kernel-level hooks needed for non-native filesystems.
install_macos() {
  install_dep macfuse
  # NOTE: there is a problem here in that this is being deprecated by homebrew
  # https://github.com/gromgit/homebrew-fuse
  HOMEBREW_NO_GITHUB_API=1 brew install gromgit/fuse/sshfs-mac
}

post_install() {
  if [[ -n "${PPM_SSH_AUTHORIZED_KEYS_URL:-}" && ! -f "$HOME/.ssh/authorized_keys" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    curl -fsSL -o "$HOME/.ssh/authorized_keys" "$PPM_SSH_AUTHORIZED_KEYS_URL"
    chmod 600 "$HOME/.ssh/authorized_keys"
  fi
}
