# Shared setup for ovm's tests.
#
# Every test runs the script straight out of the package, with HOME and the XDG dirs inside the
# per-test temp directory, so nothing reaches the real ~/vaults or the real home. Vaults are in
# ~/vaults (OVM_VAULTS_HOME's default) of that HOME. anfs's
# libraries are ANFS_TEST_LIB's (stack's convention: a core checkout's lib/anfs), else the
# installed ones (ovm lives in another source than they do), linked into the test HOME. wsm is a stub that answers `wsm ls --json`, which is how ovm reads it, from a file the
# test writes with `level`.

ovm_setup() {
  OVM="$BATS_TEST_DIRNAME/../home/.local/bin/ovm"
  local lib="${ANFS_TEST_LIB:-$HOME/.local/lib/anfs}"
  [[ -f "$lib/bash.sh" && -f "$lib/log.sh" ]] || skip "anfs's libraries are not installed at $lib"
  mkdir -p "$BATS_TEST_TMPDIR/home" "$BATS_TEST_TMPDIR/bin"
  # BATS_TEST_TMPDIR sits under /var on macOS, a symlink to /private/var; ovm stores canonical
  # paths, so HOME has to be canonical too or nothing compares equal
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
  XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
  unset ANFS_CONFIG_HOME ANFS_DATA_HOME ANFS_CACHE_HOME ANFS_STATE_HOME ANFS_DEBUG
  unset OVM_CONFIG_HOME OVM_DATA_HOME OVM_STATE_HOME OVM_CACHE_HOME OVM_VAULTS_HOME OVM_PROBE_SECONDS
  export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  export ANFS_LOG=off   # no log file from tests (lib/anfs/log.sh)
  mkdir -p "$HOME/.local/lib"
  ln -s "$(cd "$lib" && pwd -P)" "$HOME/.local/lib/anfs"
  VAULTS="$HOME/vaults"

  export WSM_LEVELS="$BATS_TEST_TMPDIR/levels"
  : > "$WSM_LEVELS"
  cat > "$BATS_TEST_TMPDIR/bin/wsm" <<'STUB'
#!/bin/sh
# wsm ls --json, from $WSM_LEVELS (id <TAB> dir, `-` for a level that is not installed)
case " $* " in *" ls "*) ;; *) exit 0 ;; esac
awk -F'\t' '
  BEGIN { printf "[" }
  { printf "%s{\"space\":\"%s\",\"dir\":%s}", (NR > 1 ? "," : ""), $1, ($2 == "-" ? "null" : "\"" $2 "\"") }
  END { print "]" }
' "$WSM_LEVELS"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/wsm"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cd "$HOME" || return 1
}

ovm() { "$OVM" "$@"; }

# A wsm level, the way wsm lists it (a source's id ends in /): installed in ~/spaces/<id>, or
# not at all with `-`
# Usage: level <id> [-]
level() {
  local id="$1"
  [[ "$id" == */* ]] || id="$id/"
  if [[ "${2:-}" == - ]]; then
    printf '%s\t-\n' "$id" >> "$WSM_LEVELS"
  else
    mkdir -p "$HOME/spaces/${id%/}"
    printf '%s\t%s\n' "$id" "$HOME/spaces/${id%/}" >> "$WSM_LEVELS"
  fi
}

# Take a level out of wsm's list (its directory stays, as after `wsm remove`)
unlevel() {
  local id="$1"
  [[ "$id" == */* ]] || id="$id/"
  grep -v "^$id	" "$WSM_LEVELS" > "$WSM_LEVELS.tmp" || true
  mv "$WSM_LEVELS.tmp" "$WSM_LEVELS"
}

# A vault at ~/vaults/<name>, initialized. Prints nothing; its id is in VID.
vault() {
  mkdir -p "$VAULTS/$1"
  ovm init "$VAULTS/$1" >/dev/null
  VID=$(yq -r .id "$VAULTS/$1/ovm.yml")
}

# A file in the test HOME: <path relative to ~> <content, \n-escaped>
file() {
  mkdir -p "$(dirname "$HOME/$1")"
  printf '%b' "$2" > "$HOME/$1"
}

# A document with frontmatter: <path relative to ~> <id> <type> [title]
doc() {
  file "$1" "---\nid: $2\ntype: $3\ntitle: \"${4:-A title}\"\n---\n\n# Body of $2\n"
}
