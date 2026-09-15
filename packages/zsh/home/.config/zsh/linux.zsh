# linux

[[ "$(os)" != "linux" ]] && return

alias bat=batcat

ip_addr() {
  ip route get 8.8.8.8 | awk '{print $7}' | head -1
}
