# nfs
#
# Linux: installs nfs-kernel-server, applies exports from ~/.config/nfs/exports.local
# macOS: configures autofs mounts from ~/.config/nfs/mounts.local

NFS_CONFIG_DIR="${HOME}/.config/nfs"

install_linux() {
  install_dep nfs-kernel-server

  # Apply exports if host-specific config exists
  if [[ -f "${NFS_CONFIG_DIR}/exports.local" ]]; then
    echo "Applying NFS exports from ${NFS_CONFIG_DIR}/exports.local"
    sudo cp "${NFS_CONFIG_DIR}/exports.local" /etc/exports
    sudo exportfs -ra
  else
    echo "No exports.local found at ${NFS_CONFIG_DIR}/exports.local"
    echo "Create this file with your export definitions, then re-run install."
    echo "See ${NFS_CONFIG_DIR}/exports.local.example for format."
  fi

  sudo systemctl enable nfs-kernel-server
  sudo systemctl start nfs-kernel-server
}

install_macos() {
  local auto_nfs="${NFS_CONFIG_DIR}/mounts.local"

  if [[ ! -f "${auto_nfs}" ]]; then
    echo "No mounts.local found at ${auto_nfs}"
    echo "Create this file with your mount definitions, then re-run install."
    echo "See ${NFS_CONFIG_DIR}/mounts.local.example for format."
    return 1
  fi

  # Create mount point directories from mounts.local
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    local mount_point=$(echo "$line" | awk '{print $1}')
    if [[ -n "$mount_point" ]]; then
      mkdir -p "$mount_point"
    fi
  done < "${auto_nfs}"

  # Install auto_nfs map
  echo "Installing autofs NFS map from ${auto_nfs}"
  sudo cp "${auto_nfs}" /etc/auto_nfs

  # Ensure auto_master includes our map
  if ! grep -q "auto_nfs" /etc/auto_master; then
    echo "Adding auto_nfs to /etc/auto_master"
    echo "/-  auto_nfs" | sudo tee -a /etc/auto_master > /dev/null
  fi

  # Restart autofs to pick up changes
  sudo automount -vc
}
