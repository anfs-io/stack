export PARA_HOME="$HOME/para"

pcd() { para cd "$@" }
pls() { para ls "$@" }

# Para shell function wrapper
para() {
  if [[ "$1" == "cd" ]]; then
    local target_dir
    local level

    # Get the logging level setting
    level=$(command para get-level 2>/dev/null)

    if [[ -z "$2" ]]; then
      # No repo specified - go to para_home
      target_dir=$(command para cd-path 2>/dev/null)
    else
      # Repo specified - find specific repository
      target_dir=$(command para cd-path "$2" 2>/dev/null)
    fi

    if [[ -n "$target_dir" && -d "$target_dir" ]]; then
      # Show output based on level setting
      if [[ "$level" == "DEBUG" ]]; then
        echo "Changing to: $target_dir"
      fi
      cd "$target_dir" || return 1
    else
      # Always show error messages regardless of level
      if [[ -z "$2" ]]; then
        echo "Para home directory not found"
      else
        echo "Repository not found: $2"
      fi
      return 1
    fi
  else
    command para "$@"
  fi
}
