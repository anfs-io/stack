# zsh.sh

install_completion() {
  local cmd="$1"
  local completion_dir=$XDG_DATA_HOME/omz/custom/completions
  local output_file="$completion_dir/_${cmd%% *}"

  mkdir -p "$completion_dir"
  if ! $cmd > "$output_file"; then
    echo "Failed to generate completion" >&2
    rm -f "$output_file"
    return 1
  fi
}
