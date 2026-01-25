# ssh
 
# SSH without host key checking
sshn() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
}

# SSHFS mount home directory
export SSH_MOUNT_HOME="$HOME/mnt"

# Mount remote filesystem via SSHFS
# Usage: ssh_mount <remote-name> [remote-path]
# Example: ssh_mount mynas /volume1/data
ssh_mount() {
  local remote_name="$1"
  local remote_path="${2:-/}"
  
  if [[ -z "$remote_name" ]]; then
    echo "Usage: sshfs_mount <remote-name> [remote-path]"
    return 1
  fi
  
  local mount_point="$SSH_MOUNT_HOME/$remote_name"
  
  mkdir -p "$mount_point"
  sshfs "$remote_name:$remote_path" "$mount_point"
  
  echo "Mounted $remote_name:$remote_path at $mount_point"
}

# Unmount helper
ssh_umount() {
  local remote_name="$1"
  
  if [[ -z "$remote_name" ]]; then
    echo "Usage: sshfs_umount <remote-name>"
    return 1
  fi
  
  umount "$SSH_MOUNT_HOME/$remote_name"
  echo "Unmounted $SSH_MOUNT_HOME/$remote_name"
}
