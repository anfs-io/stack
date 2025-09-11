# Claude commands (prefixed with cc-)

alias cc-="clear; claude"
alias cc-continue="clear; claude --continue"
alias cc-dangerously-skip-permissions="clear; claude --dangerously-skip-permissions"
alias cc-resume="clear; claude --resume"
alias cc-version="claude --version"

export CLAUDE_DIR=$HOME/claude

cc-export() {
  mkdir -p $CLAUDE_DIR

  local line="$CLAUDE_DIR 172.31.0.0/16(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000,crossmnt)"
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
  local ip_add=$(hostname -I | awk '{print $1}')
  # echo "sudo mount -t nfs -o resvport,rw,nosuid $ip_add:$CLAUDE_DIR $(hostname)"
  echo "sudo mount -t nfs -o resvport,rw,nosuid $ip_add:$CLAUDE_DIR claude"
}

cc-bind() {
  local lpath=(${(s:/:)PWD})  # Get current working directory and split by '/'

  # Check if we have exactly 4 parts (including empty first element from leading /)
  if [[ ${#lpath[@]} -ne 4 ]]; then
    echo "Error: Path must have exactly 4 parts when split by '/'"
    echo "Current path: $PWD"
    echo "Number of parts: ${#lpath[@]}"
    return 1
  fi

  local target_dir=$CLAUDE_DIR/projects/${lpath[3]}/${lpath[4]}
  local source_dir=$PWD

  if [[ "$1" == "-u" ]]; then
    echo "Unmount $source_dir at $target_dir"
  else
    echo "Bind mount $source_dir at $target_dir"
  fi

  # Output the results and confirm if user wants to bind mount
  echo ""
  echo -n "Are you sure you want to proceed? (y/n): "
  read response

  if [[ "$response" != "y" && "$response" != "Y" ]]; then
    return 1
  fi

  if [[ "$1" == "-u" ]]; then
    sudo umount -f $target_dir
    rmdir $target_dir
  else
    if [ ! -d $target_dir ]; then
      mkdir -p $target_dir
    fi
    sudo mount --bind $source_dir $target_dir
  fi
}
