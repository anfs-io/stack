# Code aliases and functions (prefixed with co-)
# Convenience functions for managing projects in the $CODE_DRI and $PROJECTS_DIR

co-export() {
  if [[ ! -d $CODE_DIR ]]; then
    echo "$CODE_DIR not found. Exiting"
    return
  fi

  local line="$CODE_DIR 172.31.0.0/16(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000,crossmnt)"
  local filename="/etc/exports"

  if grep -Fxq "$line" "$filename"; then
    echo "Line already exists in ${filename}: $line"
  else
    echo "$line" | sudo tee -a "$filename"
    echo "Added line to ${filename}: $line"
  fi

  sudo systemctl reload nfs-server
}

co-mount() {
  if [[ $1 == "ls" ]]; then
    if [[ $# -ne 2 ]]; then
      echo "must provide IP address of remote host"
      return
    fi
    if command -v showmount >/dev/null 2>&1; then
      showmount -e $2
    else
      echo "install NFS packages and retry"
    fi
  fi
  # Exports list on 172.31.16.20:
  # /home/ansible/claude                172.31.0.0/16
}

co-mount-orig() {
  if sudo exportfs -v | grep -q "$CODE_DIR"; then
    echo "sudo mount -t nfs -o resvport,rw,nosuid $ip_addr:$CODE_DIR claude"
  else
    echo "$CODE_DIR not found. Run cc-export first"
  fi
}

alias co-projects="tree -L 2 $PROJECTS_DIR"

co-repos() {
  local search_dir="${1:-$PROJECTS_DIR}"
  local current_dir=$PWD

  find "$search_dir" -maxdepth 5 -name ".git" -type d | while read gitdir; do
    local repo_path=$(dirname "$gitdir")
    local xstatus=""

    cd "$repo_path"
    if ! git diff-index --quiet HEAD 2>/dev/null || [[ -n $(git ls-files --others --exclude-standard) ]]; then
      xstatus=" - has-modifications"
    fi

    echo "$repo_path$xstatus"
  done
  cd $current_dir
}
