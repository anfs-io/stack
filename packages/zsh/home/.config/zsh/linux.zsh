# linux

[[ "$(os)" != "linux" ]] && return

if [[ -z "$HOMEBREW_PREFIX" && -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

alias bat=batcat

ip_addr() {
  ip route get 8.8.8.8 | awk '{print $7}' | head -1
}
