# macos

[[ "$(os)" != "macos" ]] && return

# Load homebrew zsh functions
if [[ -z "$HOMEBREW_PREFIX" && -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

ip_addr() {
  route get 8.8.8.8 | grep interface | awk '{print $2}' | xargs ifconfig \
    | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1
}
