#!/usr/bin/env bats
# mise's default gems for ruby are DATA (core AGENTS.md, "Where files go"): a list packages add
# to with install_gem, at ~/.local/share/ruby/default-gems; nothing writes ~/.config/ruby for it.
#
#   bats packages/ruby/tests/default-gems.bats

unset ANFS_WORK ANFS_WORK_SAID  # a person's ANFS_WORK never reaches a test (lib/anfs/work.sh)

setup() {
  PKG="$BATS_TEST_DIRNAME/.."
  HOME="$BATS_TEST_TMPDIR/home"
  export HOME
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
  # gem is a stub: every gem is already installed, nothing is fetched
  printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/gem"
  chmod +x "$BATS_TEST_TMPDIR/bin/gem"
}

@test "ruby.toml points MISE_RUBY_DEFAULT_PACKAGES_FILE under ~/.local/share" {
  run grep -x 'MISE_RUBY_DEFAULT_PACKAGES_FILE = "{{ env.HOME }}/.local/share/ruby/default-gems"' "$PKG/home/.config/mise/conf.d/ruby.toml"
  [ "$status" -eq 0 ]
  ! grep -rn '\.config/ruby/default-gems' "$PKG"/install.sh "$PKG"/home
}

@test "install_gem appends to the file in DATA, sorted, once each; nothing under ~/.config" {
  export MISE_RUBY_DEFAULT_PACKAGES_FILE="$HOME/.local/share/ruby/default-gems"
  run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash -c '
    add_to_file() { local f="$1"; shift; mkdir -p "${f%/*}"; touch "$f"
      for s in "$@"; do grep -qxF "$s" "$f" || echo "$s" >> "$f"; done; }
    source "$1"; install_gem rspec pry; install_gem pry amazing_print' _ "$PKG/home/.local/lib/ppm/ruby.sh"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(cat "$MISE_RUBY_DEFAULT_PACKAGES_FILE")" = "amazing_print
pry
rspec" ]
  [ ! -e "$HOME/.config" ]
}
