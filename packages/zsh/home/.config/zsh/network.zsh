#!/bin/zsh

# Function 1: Get local subnet
get_local_subnet() {
    # Try multiple methods to get local IP
    local local_ip
    
    # Method 1: hostname -I (Linux)
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    # Method 2: ifconfig (macOS/BSD)
    if [[ -z "$local_ip" ]]; then
        local_ip=$(ifconfig | awk '/inet / && !/127.0.0.1/ { print $2; exit }')
    fi
    
    # Method 3: ip route (Linux alternative)
    if [[ -z "$local_ip" ]]; then
        local_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '/src/ { print $7; exit }')
    fi
    
    if [[ -z "$local_ip" ]]; then
        echo "Error: Could not determine local IP" >&2
        return 1
    fi
    
    # Calculate /24 subnet
    echo $(echo $local_ip | cut -d. -f1-3).0/24
}

# Function 2: Generic port scanner for any subnet/ports (non-root)
scan_ports() {
    local subnet="$1"
    shift  # Remove first argument, rest are ports
    local ports="$*"
    
    if [[ -z "$subnet" || -z "$ports" ]]; then
        echo "Usage: scan_ports <subnet> <port1> [port2] [port3] ..." >&2
        echo "Example: scan_ports 192.168.1.0/24 22 80 443" >&2
        return 1
    fi
    
    # Convert space-separated ports to comma-separated for nmap
    local port_list=$(echo "$ports" | tr ' ' ',')
    
    # Use TCP connect scan (no root required) and save to temp file
    local temp_output=$(mktemp)
    
    nmap -T4 -sT -p "$port_list" --open "$subnet" 2>/dev/null > "$temp_output"
    
    # Parse the temp file
    local result=$(awk '
    /^Nmap scan report for/ {
        # Print previous host if it had open ports
        if (has_open_port && current_host != "") {
            print current_host
        }
        
        # Extract hostname or IP more robustly
        # Remove "Nmap scan report for " and extract everything before any parentheses
        line = $0
        gsub(/^Nmap scan report for /, "", line)
        gsub(/ \(.*\)$/, "", line)  # Remove (IP) at end if present
        current_host = line
        has_open_port = 0
    }
    /^[0-9]+\/tcp.*open/ {
        has_open_port = 1
    }
    END {
        # Handle the last host
        if (has_open_port && current_host != "") {
            print current_host
        }
    }' "$temp_output" | sort -u)
    
    # Debug output if requested
    if [[ "$CODER_OUT" == "debug" ]]; then
        echo "Debug: nmap output from $temp_output:" >&2
        cat "$temp_output" >&2
        echo "---" >&2
    fi
    
    # Clean up temp file
    rm -f "$temp_output"
    
    # Return the result
    echo "$result"
}

# Function 3: NFS scanner with optional subnet (defaults to local)
scan_nfs() {
    local subnet="${1:-$(get_local_subnet)}"
    
    if [[ -z "$subnet" ]]; then
        echo "Error: Could not determine subnet" >&2
        return 1
    fi
    
    # echo "Scanning $subnet for NFS services..." >&2
    scan_ports "$subnet" 2049 20048
}
