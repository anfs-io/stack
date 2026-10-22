#!/usr/bin/env bats
# ovm cd: the command (help, completion, what it says without the shell function), `path --dir`
# that it goes to, and the wrapper in sh/ovm.sh through core's _anfs_cd, sourced in bash and zsh
# the way core's packages/anfs/tests/cd.bats sources the core tools' wrappers.
# Run: bats packages/obsidian/tests/

load helper
setup() {
  ovm_setup
  OVM_SH="$BATS_TEST_DIRNAME/../home/.config/sh/ovm.sh"
  # anfs.sh sits next to the libraries ovm_setup linked: home/.local/lib/anfs -> home/.config/sh
  ANFS_SH="$(cd "$HOME/.local/lib/anfs" && pwd -P)/../../../.config/sh/anfs.sh"
}

need_anfs_sh() { [[ -f "$ANFS_SH" ]] || skip "core's sh/anfs.sh is not next to $HOME/.local/lib/anfs"; }

@test "cd: in help, needs the shell function, completes a vault" {
  vault notes
  run ovm help
  [[ "$output" == *"cd"*"requires the ovm shell function"* ]]
  run ovm cd notes
  [ "$status" -eq 1 ]
  [[ "$output" == *"ovm cd needs the ovm shell function (source ~/.config/sh/ovm.sh)"* ]]
  run ovm __complete cd ""
  [ "$output" = "notes"$'\t'"~/notes" ]
}

@test "path --dir: a vault's path as is, a document's directory" {
  vault notes
  doc notes/prd/one.md aaaaaaaaaa PRD
  run ovm path --dir notes
  [ "$output" = "$HOME/notes" ]
  run ovm path --dir aaaaaaaaaa
  [ "$output" = "$HOME/notes/prd" ]
  run ovm path aaaaaaaaaa
  [ "$output" = "$HOME/notes/prd/one.md" ]
  cd notes/prd
  run ovm path --dir
  [ "$output" = "$HOME/notes" ]
}

# A stub ovm: `path --dir ARG` prints ok -> target (0), stale -> stale (3), else exits 4;
# `path --dir` alone is the vault you are in (here), anything without --dir is a failure
stub_probe() {
  local T="$BATS_TEST_TMPDIR"
  mkdir -p "$T/sbin" "$T/target" "$T/stale" "$T/here"
  cat > "$T/sbin/ovm" <<STUB
#!/bin/sh
[ "\$1 \$2" = "path --dir" ] || { echo "ovm: \$*" >&2; exit 9; }
shift 2
case "\${1:-}" in
  "") echo "$T/here" ;;
  ok) echo "$T/target" ;;
  stale) echo "$T/stale"; echo "ovm: stale" >&2; exit 3 ;;
  *) echo "ovm: no \$1" >&2; exit 4 ;;
esac
STUB
  chmod +x "$T/sbin/ovm"
  cat > "$T/probe" <<PROBE
PATH="$T/sbin:/usr/bin:/bin"; unset CDPATH
. "$OVM_SH"; . "$ANFS_SH"
try() { cd "$HOME"; "\$@"; rc=\$?; echo "\$rc \$(pwd)"; }
try ovm cd ok; try ovm cd stale; try ovm cd nope; try ovm cd
PROBE
  printf '%s\n' "0 $T/target" "0 $T/stale" "4 $HOME" "0 $T/here" > "$T/expected"
}

@test "bash: the wrapper goes through _anfs_cd to ovm path --dir" {
  need_anfs_sh
  stub_probe
  run bash --norc --noprofile "$BATS_TEST_TMPDIR/probe"
  [ "$status" -eq 0 ]
  diff "$BATS_TEST_TMPDIR/expected" <(printf '%s\n' "$output" | grep -Ev '^ovm: ')
}

@test "zsh: the same" {
  need_anfs_sh
  command -v zsh >/dev/null || skip "no zsh"
  stub_probe
  run zsh -f "$BATS_TEST_TMPDIR/probe"
  [ "$status" -eq 0 ]
  diff "$BATS_TEST_TMPDIR/expected" <(printf '%s\n' "$output" | grep -Ev '^ovm: ')
}

@test "bash, the real ovm: a vault, a document's directory, the vault you are in, none outside one" {
  need_anfs_sh
  vault notes
  doc notes/prd/one.md aaaaaaaaaa PRD
  mkdir -p "$BATS_TEST_TMPDIR/rbin" elsewhere
  ln -s "$OVM" "$BATS_TEST_TMPDIR/rbin/ovm"
  run bash --norc --noprofile -c "
    PATH=\"$BATS_TEST_TMPDIR/rbin:\$PATH\"; unset CDPATH
    . \"$OVM_SH\"; . \"$ANFS_SH\"
    try() { cd \"\$1\"; shift; \"\$@\" 2>/dev/null; echo \"\$? \$(pwd)\"; }
    try \"$HOME\" ovm cd notes; try \"$HOME\" ovm cd aaaaaaaaaa
    try \"$HOME/notes/prd\" ovm cd; try \"$HOME/elsewhere\" ovm cd
    try \"$HOME\" ovm path notes"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "0 $HOME/notes" ]
  [ "${lines[1]}" = "0 $HOME/notes/prd" ]
  [ "${lines[2]}" = "0 $HOME/notes" ]
  [ "${lines[3]}" = "1 $HOME/elsewhere" ]
  [ "${lines[4]}" = "$HOME/notes" ]
}
