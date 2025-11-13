# Connect to remote hosts

ssh() {
  if (( $# == 0 )) && command -v lazyssh &>/dev/null; then
    lazyssh
  else
    command ssh "$@"
  fi
}

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
