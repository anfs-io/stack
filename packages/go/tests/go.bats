#!/usr/bin/env bats
# stack/go: GOPATH is DATA (core AGENTS.md, "Where files go"), GOBIN is GOPATH/bin and on PATH,
# the same in go.toml (mise) and sh/go.sh (the rc). Offline: a temp HOME, mise a stub that fails.
#
#   bats packages/go/tests </dev/null

unset ANFS_WORK ANFS_WORK_SAID  # a person's ANFS_WORK never reaches a test (lib/anfs/work.sh)

setup() {
  PKG="$BATS_TEST_DIRNAME/.."
  HOME="$BATS_TEST_TMPDIR/home"
  XDG_DATA_HOME="$HOME/.local/share"
  unset GOPATH GOBIN
  export HOME XDG_DATA_HOME
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
  # mise is a stub: the shell file must not need it, and nothing here installs go
  printf '#!/bin/sh\necho "mise $*" >> "%s/mise.calls"\nexit 1\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/bin/mise"
  chmod +x "$BATS_TEST_TMPDIR/bin/mise"
  # ensure_path is the rc's (core AGENTS.md, "Shell Integration"): prepend once
  RC='ensure_path() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }'
}

# Source go.sh in <shell> and print GOPATH, GOBIN and PATH's first entry
_go_env() {
  env PATH="$BATS_TEST_TMPDIR/bin:$PATH" "$1" -c "$RC"'
    . "$1"; printf "%s\n%s\n%s\n" "$GOPATH" "$GOBIN" "${PATH%%:*}"' _ "$PKG/home/.config/sh/go.sh"
}

@test "go.toml: go from mise, latest like ruby and rust" {
  run grep -x 'go = "latest"' "$PKG/home/.config/mise/conf.d/go.toml"
  [ "$status" -eq 0 ]
}

@test "go.toml: GOPATH under ~/.local/share, GOBIN its bin" {
  run grep -x 'GOPATH = "{{ env.HOME }}/.local/share/go"' "$PKG/home/.config/mise/conf.d/go.toml"
  [ "$status" -eq 0 ]
  run grep -x 'GOBIN = "{{ env.HOME }}/.local/share/go/bin"' "$PKG/home/.config/mise/conf.d/go.toml"
  [ "$status" -eq 0 ]
}

@test "go.sh in bash: GOPATH in DATA, GOBIN first on PATH, no mise, nothing written" {
  run _go_env bash
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "${lines[0]}" = "$HOME/.local/share/go" ]
  [ "${lines[1]}" = "$HOME/.local/share/go/bin" ]
  [ "${lines[2]}" = "$HOME/.local/share/go/bin" ]
  [ ! -e "$BATS_TEST_TMPDIR/mise.calls" ]
  [ -z "$(ls -A "$HOME")" ]
}

@test "go.sh in zsh: the same" {
  command -v zsh >/dev/null || skip "no zsh"
  run _go_env zsh
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "${lines[0]}" = "$HOME/.local/share/go" ]
  [ "${lines[1]}" = "$HOME/.local/share/go/bin" ]
  [ "${lines[2]}" = "$HOME/.local/share/go/bin" ]
}

@test "go.sh twice: GOBIN on PATH once" {
  run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash -c "$RC"'
    . "$1"; . "$1"; echo "$PATH" | tr : "\n" | grep -cxF "$GOBIN"' _ "$PKG/home/.config/sh/go.sh"
  [ "$output" = 1 ]
}
