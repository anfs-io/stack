# ssh

# SSH without host key checking
sshn() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
}
