# network-tools

netperf() {
  local ts_ip="${1:-100.108.218.1}"
  local uf_ip="${2:-172.31.9.11}"
  local duration="${3:-10}"

  echo "=== Tailscale (${ts_ip}) ==="
  echo "-- Upload --"
  iperf3 -c $ts_ip -t $duration
  echo ""
  echo "-- Download --"
  iperf3 -c $ts_ip -t $duration -R
  echo ""

  echo "=== UniFi Mesh (${uf_ip}) ==="
  echo "-- Upload --"
  iperf3 -c $uf_ip -t $duration
  echo ""
  echo "-- Download --"
  iperf3 -c $uf_ip -t $duration -R
}

scan_ports() {
  local subnet="$1"
  shift
  local ports="$*"

  if [[ -z "$subnet" || -z "$ports" ]]; then
    echo "Usage: scan_ports <subnet> <port1> [port2] [port3] ..." >&2
    echo "Example: scan_ports 192.168.1.0/24 22 80 443" >&2
    return 1
  fi

  local port_list=$(echo "$ports" | tr ' ' ',')
  local temp_output=$(mktemp)

  nmap -T4 -sT -p "$port_list" --open "$subnet" 2>/dev/null > "$temp_output"

  local result=$(awk '
  /^Nmap scan report for/ {
    if (has_open_port && current_host != "") {
      print current_host
    }
    line = $0
    gsub(/^Nmap scan report for /, "", line)
    gsub(/ \(.*\)$/, "", line)
    current_host = line
    has_open_port = 0
  }
  /^[0-9]+\/tcp.*open/ {
    has_open_port = 1
  }
  END {
    if (has_open_port && current_host != "") {
      print current_host
    }
  }' "$temp_output" | sort -u)

  rm -f "$temp_output"
  echo "$result"
}
