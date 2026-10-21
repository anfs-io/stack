#!/usr/bin/env bats
# install.sh: the wsm listener ovm registers, and the one-time carry-over from pvm (the state
# directory, and pvm.yml renamed to ovm.yml in each registered vault). The hooks run in a bash
# that sources install.sh with ppm's functions stubbed: each prints what it was given.
# Run: bats packages/obsidian/tests/

load helper
setup() {
  ovm_setup
  PKG="$BATS_TEST_DIRNAME/.."
  OLD="$XDG_STATE_HOME/pvm" NEW="$XDG_STATE_HOME/ovm"
}

hook() {
  PPM_CURRENT_PACKAGE=stack/obsidian bash -c '
    user_message() { local a m=""; for a in "$@"; do m="$m${a#"${a%%[![:space:]]*}"}"; done; echo "msg: $m"; }
    anfs_callback_register() { echo "register: $*"; }
    anfs_callback_unregister() { echo "unregister: $*"; }
    source "$1/install.sh"; "$2"' _ "$PKG" "$1"
}

# What pvm left: two vaults, `notes` with pvm.yml and a link into a level, and `done` already on
# ovm.yml (renamed by hand), all recorded under $XDG_STATE_HOME/pvm
pvm_state() {
  level acme
  vault notes
  vault done
  DONE_ID=$VID
  NOTES_ID=$(yq -r .id "$HOME/notes/ovm.yml")
  mkdir -p notes/product
  ovm link add notes/product --to acme >/dev/null
  mv "$HOME/notes/ovm.yml" "$HOME/notes/pvm.yml"
  mv "$NEW" "$OLD"
  cp "$OLD/vaults" "$BATS_TEST_TMPDIR/vaults.before"
  cp "$OLD/links" "$BATS_TEST_TMPDIR/links.before"
}

@test "post_install registers ovm's wsm listener; post_remove unregisters it" {
  run hook post_install
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "register: wsm stack/obsidian ovm link apply --event" ]]
  [[ "$output" == *"ovm init <dir>"* ]]
  [[ "$output" != *pvm* ]]
  run hook post_remove
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "unregister: wsm stack/obsidian" ]]
}

@test "migration: the state moves, pvm.yml becomes ovm.yml, ids and links are kept; then ovm sees them ok" {
  pvm_state
  run hook post_install
  [ "$status" -eq 0 ]
  [ ! -e "$OLD" ]
  cmp "$NEW/vaults" "$BATS_TEST_TMPDIR/vaults.before"
  cmp "$NEW/links" "$BATS_TEST_TMPDIR/links.before"
  [ ! -e "$HOME/notes/pvm.yml" ]
  [ "$(yq -r .id "$HOME/notes/ovm.yml")" = "$NOTES_ID" ]
  [ "$(yq -r .id "$HOME/done/ovm.yml")" = "$DONE_ID" ]
  # One line for the vault renamed, none for the one already on ovm.yml
  [ "$(grep -c 'renamed pvm.yml' <<< "$output")" -eq 1 ]
  [[ "$output" == *"Vault notes ($NOTES_ID): renamed pvm.yml to ovm.yml in $HOME/notes"* ]]
  [[ "$output" != *"Vault done"* ]]
  run ovm ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"notes"$'\t'"$NOTES_ID"$'\t'"ok"* ]]
  [[ "$output" == *"done"$'\t'"$DONE_ID"$'\t'"ok"* ]]
  run ovm link ls notes
  [[ "${lines[0]}" == "product"$'\t'"acme"$'\t'"product"$'\t'"ok"$'\t'* ]]
}

@test "migration: a second run does nothing and says nothing of pvm" {
  pvm_state
  hook post_install >/dev/null
  run hook post_install
  [ "$status" -eq 0 ]
  [[ "$output" != *pvm* ]]
  [ ! -e "$OLD" ]
}

@test "migration: with both pvm/ and ovm/ present nothing moves, and it is said once" {
  pvm_state
  mkdir -p "$NEW"
  run hook post_install
  [ "$status" -eq 0 ]
  [ -f "$OLD/vaults" ]
  [ ! -e "$NEW/vaults" ]
  [ -f "$HOME/notes/pvm.yml" ]
  [ "$(grep -c 'nothing was carried over from pvm' <<< "$output")" -eq 1 ]
}

@test "migration: no pvm state is silent" {
  run hook post_install
  [ "$status" -eq 0 ]
  [[ "$output" != *pvm* ]]
  [ ! -e "$NEW" ]
}

@test "migration: a vault whose path is gone is skipped with the manual step" {
  pvm_state
  mv "$HOME/done" "$HOME/elsewhere"
  run hook post_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Vault done ($DONE_ID) at $HOME/done did not answer: rename its pvm.yml to ovm.yml by hand."* ]]
  [[ "$output" == *"Vault notes ($NOTES_ID): renamed"* ]]
  [ -f "$HOME/elsewhere/ovm.yml" ]
}
