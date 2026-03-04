# pde/chorus
 
chorus_init() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: chorus_init <repo_url> <space_name>" >&2
    return 1
  fi

  if [[ -z "$CHORUS_PATH" ]]; then
    echo "CHORUS_PATH is not set" >&2
    return 1
  fi

  local chorus_repo=$1
  local chorus_repo_path=$CHORUS_PATH/$2

  if [[ -d "$chorus_repo_path" ]]; then
    echo "Directory already exists: $chorus_repo_path" >&2
    return 1
  fi

  git clone "$chorus_repo" "$chorus_repo_path" || return 1
  pushd "$chorus_repo_path" > /dev/null
  chorus init
  popd > /dev/null
}
