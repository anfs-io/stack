# macos

[[ "$(os)" != "macos" ]] && return

ip_addr() {
  local iface line ip_cidr ip

  # Get active network interface name
  iface=$(route -n get 8.8.8.8 2>/dev/null | awk '/interface:/ {print $2}')
  [[ -z "$iface" ]] && return 1

  # Extract "IP/CIDR" directly using -f inet:cidr
  ip_cidr=$(ifconfig -f inet:cidr "$iface" | awk '/inet / && !/127\.0\.0\.1/ {print $2; exit}')
  [[ -z "$ip_cidr" ]] && return 1

  if [[ -n "$1" ]]; then
    echo "$ip_cidr"
  else
    echo "${ip_cidr%%/*}"
  fi
}

alias up="caffeinate -d"
