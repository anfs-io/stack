# pde/gems

GEMS_SOURCE="$XDG_DATA_HOME/gems-source"
GEMS_ROOT="$XDG_DATA_HOME/gems"

REPOS=(
  "git@github.com:rjayroach/gems.git"
  "git@github.com:cnfs-io/gems.git"
  "git@github.com:anfs-io/gems.git"
)

post_install() {
  mkdir -p "$GEMS_SOURCE" "$GEMS_ROOT"

  for url in "${REPOS[@]}"; do
    # git@github.com:owner/repo.git -> owner
    local owner="${url#*:}"
    owner="${owner%%/*}"
    local target="$GEMS_SOURCE/$owner"

    if [[ -d "$target/.git" ]]; then
      user_message "Pulled $owner into $target"
      git -C "$target" pull --quiet
    else
      user_message "Cloned $owner into $target"
      git clone --quiet "$url" "$target"
    fi
  done

  # Create per-gem symlinks in GEMS_ROOT
  for gemdir in "$GEMS_SOURCE"/*/*/; do
    ls "$gemdir"/*.gemspec &>/dev/null || continue
    local gem_name="$(basename "$gemdir")"
    local link="$GEMS_ROOT/$gem_name"
    if [[ ! -L "$link" ]]; then
      ln -s "$gemdir" "$link"
      user_message "Linked $gem_name"
    fi
  done

  "$GEMS_ROOT/install.sh"
}

post_remove() {
  rm -rf "$GEMS_SOURCE" "$GEMS_ROOT"
}
