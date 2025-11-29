# Connect to remote hosts

if command -v lazyssh &>/dev/null; then
  ssh() {
    if (( $# == 0 )); then
      lazyssh
    else
      command ssh "$@"
    fi
  }
fi

con() {
  local site=$PCS_SITE
  if (( $# == 1 )); then
    site="lab$1"
  fi
  ssh rpi1.mgmt.$site.rjayroach.com
}

pve() {
  local site=$PCS_SITE
  if (( $# == 2 )); then
    site="lab$2"
  fi
  ssh pve$1.mgmt.$site.rjayroach.com
}
