# podman

install_linux() {
  _podman_subids

  # Podman API socket for docker-compatible clients (dockge, dev containers, testcontainers)
  if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user enable --now podman.socket
  else
    user_message "No systemd user session, so the podman API socket was not enabled.\nRun 'podman system service --time=0 &' when a docker-compatible client needs it."
  fi
}

# Rootless podman maps container IDs onto a subordinate range from /etc/subuid and /etc/subgid.
# useradd allocates one only if those files already exist, so an account created before uidmap
# was installed (Debian ships them in uidmap) has none, and podman fails with "newuidmap" or
# "no subuid ranges found". Give the user the next free 65536 IDs, then have podman re-read them.
_podman_subids() {
  local user f start next have_uid=false have_gid=false
  user=$(id -un)
  grep -q "^$user:" /etc/subuid 2>/dev/null && have_uid=true
  grep -q "^$user:" /etc/subgid 2>/dev/null && have_gid=true
  $have_uid && $have_gid && return 0

  # First ID past every range already handed out in either file, 100000 at the least
  start=100000
  for f in /etc/subuid /etc/subgid; do
    [[ -r "$f" ]] || continue
    next=$(awk -F: '$2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ { e = $2 + $3; if (e > m) m = e } END { print m + 0 }' "$f")
    (( next > start )) && start=$next
  done

  local range="$start-$((start + 65535))" args=()
  $have_uid || args+=(--add-subuids "$range")
  $have_gid || args+=(--add-subgids "$range")
  _system_sudo "subordinate IDs for $user" \
    "Rootless podman needs subordinate IDs for $user; run: sudo usermod ${args[*]} $user && podman system migrate" ||
    return 0
  sudo -n usermod "${args[@]}" "$user" || { ppm_fail "usermod ${args[*]} $user failed"; return 0; }
  podman system migrate >/dev/null 2>&1 || true
  user_message "Gave $user subordinate IDs $range for rootless podman"
}

install_macos() {
  # The podman API socket runs inside the podman machine VM; nothing to enable here.
  # Clients running in containers get its VM-side path from:
  #   podman info --format '{{.Host.RemoteSocket.Path}}'

  if ! podman machine list --format "{{.Name}}" | grep -q "podman-machine-default"; then
    podman machine init
  fi

  # if ! podman machine list --format "{{.Running}}" | grep -q "true"; then
  #   podman machine start
  # fi

  # You need it for tools that expect the Docker socket at the standard location - like LocalStack, docker-compose, or other tools that don't read $DOCKER_HOST reliably.
  # If podman ps works and LocalStack also works with your current $DOCKER_HOST setup, you might not need the helper at all.
  # if [[ ! -S /var/run/docker.sock ]]; then
  #   sudo $HOMEBREW_PREFIX/bin/podman-mac-helper install
  # fi
}
