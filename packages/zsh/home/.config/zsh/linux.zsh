# linux

[[ "$(os)" != "linux" ]] && return

# Debian's apt package installs the binary as batcat; Homebrew's is bat
command -v bat >/dev/null || alias bat=batcat

ip_addr() {
  ip route get 8.8.8.8 | awk '{print $7}' | head -1
}
