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
  unset ANFS_WORK ANFS_WORK_SAID  # a person's ANFS_WORK never reaches a test (lib/anfs/work.sh)
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

  # ovm's library (~/.local/lib/ovm): the package's skeleton and fixture pins, and curl a stub that
  # serves the fixture releases and logs each URL. No test reaches the network.
  _ovm_fixture_lib
  ln -s "$BATS_FILE_TMPDIR/ovm-fixture/lib" "$HOME/.local/lib/ovm"
  export OVM_RELEASES="$BATS_TEST_TMPDIR/releases" CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
  cp -R "$BATS_FILE_TMPDIR/ovm-fixture/releases" "$OVM_RELEASES"
  : > "$CURL_LOG"
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
# curl -o <file> <url>: https://github.com/<path> from $OVM_RELEASES/<path>; anything else fails as
# a 404 does (22)
out="" url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    --retry) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf '%s\n' "$url" >> "$CURL_LOG"
src="$OVM_RELEASES/${url#https://github.com/}"
[[ "$url" == https://github.com/* && -f "$src" && -n "$out" ]] || exit 22
cp "$src" "$out"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cd "$HOME" || return 1
}

# The three pins of the real plugins.yml, each at a fixture version 1.0.0: small assets (a
# manifest.json with the plugin's id) under $BATS_FILE_TMPDIR/ovm-fixture/releases/<repo>/releases/
# download/1.0.0/, and a plugins.yml with their sha256s beside the package's real vault/ skeleton.
# Built once per file.
FIXTURE_PINS="templater-obsidian:SilentVoid13/Templater obsidian-shellcommands:Taitava/obsidian-shellcommands obsidian-meta-bind-plugin:mProjectsCode/obsidian-meta-bind-plugin"
_ovm_fixture_lib() {
  local base="$BATS_FILE_TMPDIR/ovm-fixture" spec id repo d a
  [[ -f "$base/lib/plugins.yml" ]] && return 0
  mkdir -p "$base/lib"
  ln -s "$(cd "$BATS_TEST_DIRNAME/../home/.local/lib/ovm/vault" && pwd -P)" "$base/lib/vault"
  for spec in $FIXTURE_PINS; do
    id=${spec%%:*} repo=${spec#*:}
    d="$base/releases/$repo/releases/download/1.0.0"
    mkdir -p "$d"
    printf '// %s 1.0.0\n' "$id" > "$d/main.js"
    printf '{\n  "id": "%s",\n  "name": "%s",\n  "version": "1.0.0"\n}\n' "$id" "$id" > "$d/manifest.json"
    printf '/* %s 1.0.0 */\n' "$id" > "$d/styles.css"
    printf '%s:\n  repo: %s\n  version: 1.0.0\n  sha256:\n' "$id" "$repo" >> "$base/lib/plugins.yml.tmp"
    for a in main.js manifest.json styles.css; do
      printf '    %s: %s\n' "$a" "$(sha256 "$d/$a")" >> "$base/lib/plugins.yml.tmp"
    done
  done
  mv "$base/lib/plugins.yml.tmp" "$base/lib/plugins.yml"
}

# The sha256 of <file>
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# A plugin's files as if installed at <version> in vault <name>: <name> <id> <version>
plugin_at() {
  local d="$VAULTS/$1/.obsidian/plugins/$2"
  mkdir -p "$d"
  printf '// %s %s\n' "$2" "$3" > "$d/main.js"
  printf '{"id": "%s", "version": "%s"}\n' "$2" "$3" > "$d/manifest.json"
  printf '/* %s */\n' "$3" > "$d/styles.css"
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
  ovm init --no-plugins "$VAULTS/$1" >/dev/null
  VID=$(yq -r .id "$VAULTS/$1/vault.yml")
}

# ~/.config/ovm/links.yml, from <yaml> (\n-escaped)
links() {
  mkdir -p "$XDG_CONFIG_HOME/ovm"
  printf '%b' "$1" > "$XDG_CONFIG_HOME/ovm/links.yml"
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
