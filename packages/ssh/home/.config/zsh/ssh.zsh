# ssh

# SSH without host key checking
sshn() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
}

# SSHFS env vars
export SSHFS_CONFIG_HOME="$XDG_CONFIG_HOME/sshfs/mounts.d"
export SSHFS_DATA_HOME="$HOME/mnt"

# Usage: ssh_mount [label] [host] [rpath]
ssh_mount() {
  local label="$1" host="$2" rpath="$3"

  if [[ -z "$label" ]]; then
    grep -rh '' "$SSHFS_CONFIG_HOME" 2>/dev/null | while read -r l h p; do
      local status=""; mountpoint -q "$SSHFS_DATA_HOME/$l" 2>/dev/null && status="$SSHFS_DATA_HOME/$l"
      echo "$l $h $p $status"
    done
    return
  fi

  if [[ -z "$host" ]]; then
    local entry=$(grep -rh "^$label " "$SSHFS_CONFIG_HOME" 2>/dev/null | head -1)
    [[ -z "$entry" ]] && { echo "Label '$label' not found"; return 1; }
    read -r _ host rpath <<< "$entry"
  else
    mkdir -p "$SSHFS_CONFIG_HOME"
    grep -rqh "^$label " "$SSHFS_CONFIG_HOME" 2>/dev/null || echo "$label $host ${rpath:-.}" >> "$SSHFS_CONFIG_HOME/mounts.conf"
  fi

  mkdir -p "$SSHFS_DATA_HOME/$label"
  sshfs "$host:${rpath:-.}" "$SSHFS_DATA_HOME/$label" && echo "Mounted $host:${rpath:-.} at $SSHFS_DATA_HOME/$label"
}

# Usage: ssh_umount <label>
ssh_umount() {
  local label="$1"
  [[ -z "$label" ]] && { echo "Usage: ssh_umount <label>"; return 1; }
  umount "$SSHFS_DATA_HOME/$label" && rmdir "$SSHFS_DATA_HOME/$label" && echo "Unmounted $label"
}
