# Claude aliases and functions (prefixed with cc-)

# Shortcuts
alias cc="clear; claude"
alias cc-continue="clear; claude --continue"
alias cc-dangerously-skip-permissions="clear; claude --dangerously-skip-permissions"
alias cc-resume="clear; claude --resume"
alias cc-version="claude --version"

# Custom aliases and functions
alias cc-ls="tree -L 2 $PROJECTS_DIR"

cc-export() {
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

cc-mount() {
  if [[ ! -d $CODE_DIR ]]; then
    echo "$CODE_DIR not found. Nothing to mount"
    return
  fi

  local ip_add=$(hostname -I | awk '{print $1}')
  echo "sudo mount -t nfs -o resvport,rw,nosuid $ip_add:$CODE_DIR claude"
}
