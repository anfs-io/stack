#!/usr/bin/env bats
# gem-local — offline: a temp HOME, no bundler (build is not run).
#
#   bats packages/ruby/tests/gem-local.bats

unset ANFS_WORK ANFS_WORK_SAID  # a person's ANFS_WORK never reaches a test (lib/anfs/work.sh)

setup() {
  GL="$BATS_TEST_DIRNAME/../home/.local/bin/gem-local"
  local lib="${ANFS_TEST_LIB:-$HOME/.local/lib/anfs}"
  [[ -f "$lib/bash.sh" && -f "$lib/table.sh" ]] || skip "anfs's libraries are not installed at $lib"
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/lib"
  ln -s "$(cd "$lib" && pwd -P)" "$BATS_TEST_TMPDIR/home/.local/lib/anfs"
  # Canonical, so the paths gem-local resolves compare equal (/var is a symlink on macOS)
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
  XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
  unset RUBY_LOCAL_GEMS_HOME RUBY_LOCAL_GEMS_CONFIG ANFS_DEBUG ANFS_JSON
  export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  export ANFS_LOG=off ANFS_TABLE=tsv
  CONFIG="$XDG_CONFIG_HOME/ruby/local-gems"
  GEMS="$XDG_DATA_HOME/gems"
  mkdir -p "$HOME/repo/alpha" "$GEMS"
  touch "$HOME/repo/alpha/alpha.gemspec"
  cd "$HOME"
}

@test "help lists the commands, and an unknown one is a usage error" {
  run "$GL" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"src <list|add|remove>"* ]]
  run "$GL" bogus
  [ "$status" -eq 64 ]
}

@test "an unknown option is refused with the command's usage line" {
  run "$GL" list --bogus
  [ "$status" -eq 64 ]
  [[ "$output" == *"unknown option '--bogus'"* ]]
  [[ "$output" == *"usage: gem-local list"* ]]
}

@test "src add writes the path with ~, once" {
  run "$GL" src add repo
  [ "$status" -eq 0 ]
  [ "$(cat "$CONFIG")" = "~/repo" ]
  run "$GL" src add "$HOME/repo"
  [[ "$output" == *"Already configured"* ]]
  [ "$(wc -l < "$CONFIG" | tr -d ' ')" = 1 ]
}

@test "src list: rows piped, objects with --json, a missing dir noted" {
  printf '%s\n' "~/repo" "~/gone" > "$(mkdir -p "${CONFIG%/*}" && echo "$CONFIG")"
  run "$GL" src list
  [ "${lines[0]}" = "~/repo"$'\t'"-" ]
  [ "${lines[1]}" = "~/gone"$'\t'"missing" ]
  run env -u ANFS_TABLE "$GL" src ls --json
  [ "$output" = "[{\"path\":\"$HOME/repo\",\"note\":null},{\"path\":\"$HOME/gone\",\"note\":\"missing\"}]" ]
}

@test "src remove takes rm, and a dir that is gone" {
  mkdir -p "${CONFIG%/*}"
  printf '%s\n' "# mine" "~/repo" "~/gone" > "$CONFIG"
  run "$GL" src rm "~/gone"
  [ "$status" -eq 0 ]
  run "$GL" src remove repo
  [ "$status" -eq 0 ]
  [ "$(cat "$CONFIG")" = "# mine" ]
}

@test "list, path and completion read the links" {
  ln -s "$HOME/repo/alpha" "$GEMS/alpha"
  ln -s "$HOME/repo/beta" "$GEMS/beta"
  run "$GL" ls
  [ "${lines[0]}" = "alpha"$'\t'"~/repo/alpha"$'\t'"-" ]
  [ "${lines[1]}" = "beta"$'\t'"~/repo/beta"$'\t'"missing" ]
  run "$GL" path alpha
  [ "$output" = "$HOME/repo/alpha" ]
  run "$GL" path beta
  [ "$status" -eq 1 ]
  run "$GL" __complete path ""
  [ "$output" = "alpha"$'\n'"beta" ]
}

@test "no gems: a hint on stderr, and [] with --json" {
  run "$GL" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no gems linked"* ]]
  run env -u ANFS_TABLE "$GL" list --json
  [ "$output" = "[]" ]
}
