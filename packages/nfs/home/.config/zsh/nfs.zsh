# nfs

nfs_status() {
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "=== autofs mounts ==="
    mount | grep nfs
  else
    echo "=== NFS exports ==="
    exportfs -v 2>/dev/null || echo "(exportfs not available or not root)"
    echo ""
    echo "=== Active NFS connections ==="
    ss -tn state established '( sport = :2049 )' 2>/dev/null || \
      netstat -tn 2>/dev/null | grep ":2049"
  fi
}

nfs_remount() {
  if [[ "$(uname)" == "Darwin" ]]; then
    sudo automount -vc
  else
    sudo exportfs -ra
    echo "Exports reloaded."
  fi
}
