# pdt/gems

GEMS_ROOT="$XDG_DATA_HOME/gems"

REPOS=(
  "rjayroach:git@github.com:rjayroach/gems.git"
  "cnfs:git@github.com:cnfs-io/gems.git"
  "anfs:git@github.com:anfs-io/gems.git"
)

dependencies() {
  echo "ruby"
}

post_install() {
  mkdir -p "$GEMS_ROOT"

  for entry in "${REPOS[@]}"; do
    local dir="${entry%%:*}"
    local url="${entry#*:}"
    local target="$GEMS_ROOT/$dir"

    if [[ -d "$target/.git" ]]; then
      echo "Pulling $dir..."
      git -C "$target" pull --quiet
    else
      echo "Cloning $dir..."
      git clone --quiet "$url" "$target"
    fi
  done

  # Foundation first, then the rest
  "$GEMS_ROOT/install.sh"
}
