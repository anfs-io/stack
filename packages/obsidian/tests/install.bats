#!/usr/bin/env bats
# install.sh: the wsm listener ovm registers. The hooks run in a bash that sources install.sh
# with ppm's functions stubbed: each prints what it was given.
# Run: bats packages/obsidian/tests/

load helper
setup() {
  ovm_setup
  PKG="$BATS_TEST_DIRNAME/.."
}

hook() {
  PPM_CURRENT_PACKAGE=stack/obsidian bash -c '
    user_message() { local a m=""; for a in "$@"; do m="$m${a#"${a%%[![:space:]]*}"}"; done; echo "msg: $m"; }
    anfs_callback_register() { echo "register: $*"; }
    anfs_callback_unregister() { echo "unregister: $*"; }
    source "$1/install.sh"; "$2"' _ "$PKG" "$1"
}

@test "post_install registers ovm's wsm listener; post_remove unregisters it" {
  run hook post_install
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "register: wsm stack/obsidian ovm space apply --event" ]]
  [[ "$output" == *"ovm new <name>"* ]]
  run hook post_remove
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "unregister: wsm stack/obsidian" ]]
}
