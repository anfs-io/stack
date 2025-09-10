# shortcuts for pcs functions

pcs-adopt() {
  wget -qO- https://raw.githubusercontent.com/maxcole/pcs-bootstrap/refs/heads/main/adopt.sh | sudo bash -s -- all
}

pcs-control() {
  valid=("rws" "roteoh")
  valid_string="|$(IFS='|'; echo "${valid[*]}")|"

  if [[ "$valid_string" != *"|$1|"* ]]; then
    echo "arg must be 'rws' or 'roteoh'"
    return
  fi

  local repo_dir=$(git-clone $1-controller)
  (cd $repo_dir/ansible; ./controller.yml)
}
