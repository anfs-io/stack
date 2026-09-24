# Shared setup for wsm's tests.
#
# Every test runs the script straight out of the package, with HOME and XDG_STATE_HOME inside
# the per-test temp directory, so nothing reaches the real registry or the real home.

wsm_setup() {
  WSM="$BATS_TEST_DIRNAME/../home/.local/bin/wsm"
  mkdir -p "$BATS_TEST_TMPDIR/home" "$BATS_TEST_TMPDIR/state"
  # BATS_TEST_TMPDIR sits under /var on macOS, which is a symlink to /private/var. wsm
  # canonicalizes every path it stores, so HOME has to be canonical too or nothing compares equal.
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  XDG_STATE_HOME=$(cd "$BATS_TEST_TMPDIR/state" && pwd -P)
  export HOME XDG_STATE_HOME
  REGISTRY="$XDG_STATE_HOME/wsm/workspaces"
  cd "$HOME" || return 1
}

wsm() { "$WSM" "$@"; }

# A directory with a marker but no registry entry — what a freshly cloned workspace looks like
mkmarker() {
  mkdir -p "$HOME/$1/.wsm"
  printf '%s\n' "${2:-$(uuidgen | tr '[:upper:]' '[:lower:]')}" > "$HOME/$1/.wsm/id"
}

entries() {
  [[ -f "$REGISTRY" ]] || { echo 0; return 0; }
  grep -c . "$REGISTRY" || true
}

# field <match> <n> — column n of the registry line containing <match>
field() { grep -F "$1" "$REGISTRY" | cut -f"$2"; }

# A bare repo under $BATS_TEST_TMPDIR/bare, cloneable over file://. Prints its path.
# Usage: mkbare <name> [extra-branch]
mkbare() {
  local name="$1" branch="${2:-}" work="$BATS_TEST_TMPDIR/src/$1"
  mkdir -p "$work" "$BATS_TEST_TMPDIR/bare"
  git -C "$work" init -q
  git -C "$work" config user.email t@t
  git -C "$work" config user.name tester
  echo "$name" > "$work/README"
  git -C "$work" add -A
  git -C "$work" commit -q -m "init $name"
  if [[ -n "$branch" ]]; then
    git -C "$work" checkout -q -b "$branch"
    echo "on $branch" > "$work/BRANCH"
    git -C "$work" add -A
    git -C "$work" commit -q -m "$branch"
    git -C "$work" checkout -q -
  fi
  git clone -q --bare "$work" "$BATS_TEST_TMPDIR/bare/$name.git"
  printf '%s\n' "$BATS_TEST_TMPDIR/bare/$name.git"
}

# Write a workspace's resources file from stdin
# Usage: resources <workspace-path> [filename]  < body
resources() {
  mkdir -p "$HOME/$1/.wsm"
  cat > "$HOME/$1/.wsm/${2:-resources}"
}
