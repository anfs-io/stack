# linux

[[ "$(os)" != "linux" ]] && return

# Debian's apt package installs the binary as batcat; Homebrew's is bat
command -v bat >/dev/null || alias bat=batcat

ip_addr() {
  local iface line ip_cidr

  # Get active network interface name via route lookup
  iface=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $5; exit}')
  [[ -z "$iface" ]] && return 1

  # Extract "IP/CIDR" directly from ip address output
  ip_cidr=$(ip -4 -br addr show dev "$iface" 2>/dev/null | awk '{print $3; exit}')
  [[ -z "$ip_cidr" ]] && return 1

  if [[ -n "$1" ]]; then
    echo "$ip_cidr"
  else
    echo "${ip_cidr%%/*}"
  fi
}
