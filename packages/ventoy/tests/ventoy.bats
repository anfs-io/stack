#!/usr/bin/env bats
# ventoy — offline: a temp HOME, the stick is a directory, nothing is mounted or downloaded.
# The Linux disk list is read from stubbed `uname` and `lsblk`.
#
#   bats packages/ventoy/tests/ventoy.bats

setup() {
  VENTOY="$BATS_TEST_DIRNAME/../home/.local/bin/ventoy"
  local lib="${ANFS_TEST_LIB:-$HOME/.local/lib/anfs}"
  [[ -f "$lib/bash.sh" && -f "$lib/table.sh" && -f "$lib/iso.sh" ]] || skip "anfs's libraries are not installed at $lib"
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/lib" "$BATS_TEST_TMPDIR/bin"
  ln -s "$(cd "$lib" && pwd -P)" "$BATS_TEST_TMPDIR/home/.local/lib/anfs"
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
  XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
  unset VENTOY_HOME VENTOY_ISO_DIR VENTOY_DISK ANFS_DEBUG ANFS_JSON
  unset ANFS_CONFIG_HOME ANFS_DATA_HOME ANFS_CACHE_HOME ANFS_STATE_HOME ANFS_ISO_HOME
  unset VENTOY_CONFIG_HOME VENTOY_DATA_HOME VENTOY_STATE_HOME VENTOY_CACHE_HOME
  export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  export ANFS_LOG=off ANFS_TABLE=tsv
  ISOS="$XDG_CACHE_HOME/ventoy/isos"
  STICK="$HOME/stick"
  STORE="$XDG_CACHE_HOME/anfs/isos"
  mkdir -p "$ISOS" "$STICK" "$STORE" "$XDG_CONFIG_HOME/anfs"
  cat > "$XDG_CONFIG_HOME/anfs/isos.yml" <<'EOF'
---
- id: debian
  url: https://example.invalid/debian.iso
  filename: debian-13.iso
- id: arch
  url: https://example.invalid/arch.iso
EOF
  cd "$HOME"
}

@test "help lists the commands, and an unknown one is a usage error" {
  run "$VENTOY" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"list, ls [target]"* ]]
  [[ "$output" == *"VENTOY_ISO_DIR"* ]]
  run "$VENTOY" bogus
  [ "$status" -eq 64 ]
}

@test "an unknown option is refused with the command's usage line" {
  run "$VENTOY" sync --bogus
  [ "$status" -eq 64 ]
  [[ "$output" == *"usage: ventoy sync [-n] [-y] [target]"* ]]
}

@test "list: what is on the stick, what differs, what is not copied" {
  printf 'aaaa' > "$ISOS/same.iso";  printf 'aaaa' > "$STICK/same.iso"
  printf 'aaaa' > "$ISOS/diff.iso";  printf 'aa'   > "$STICK/diff.iso"
  printf 'aaaa' > "$ISOS/new.iso"
  printf 'aaaa' > "$STICK/extra.iso"
  run "$VENTOY" ls "$STICK"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\t'"differs"$'\t'"diff.iso"* ]]
  [[ "$output" == *$'\t'"only on stick"$'\t'"extra.iso"* ]]
  [[ "$output" == *$'\t'"on stick"$'\t'"same.iso"* ]]
  [[ "$output" == *$'\t'"not copied"$'\t'"new.iso"* ]]
  run env -u ANFS_TABLE "$VENTOY" list "$STICK" --json
  [[ "$output" == *'"status":"not copied","iso":"new.iso"}'* ]]
}

@test "sync -n says what would change and changes nothing" {
  printf 'aaaa' > "$ISOS/new.iso"
  printf 'aaaa' > "$STICK/extra.iso"
  run "$VENTOY" sync -n "$STICK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"remove"*"extra.iso"* ]]
  [[ "$output" == *"copy"*"new.iso"* ]]
  [ -f "$STICK/extra.iso" ] && [ ! -f "$STICK/new.iso" ]
}

@test "sync asks: refused without a terminal, done with -y" {
  printf 'aaaa' > "$ISOS/new.iso"
  printf 'aaaa' > "$STICK/extra.iso"
  run "$VENTOY" sync "$STICK" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"pass -y"* ]]
  [ -f "$STICK/extra.iso" ]
  run "$VENTOY" sync "$STICK" -y </dev/null
  [ "$status" -eq 0 ]
  [ ! -f "$STICK/extra.iso" ] && [ -f "$STICK/new.iso" ]
}

@test "remove takes rm and --target, and refuses a path off the stick" {
  printf 'aaaa' > "$STICK/a.iso"
  run "$VENTOY" rm a.iso -t "$STICK"
  [ "$status" -eq 0 ]
  [ ! -f "$STICK/a.iso" ]
  run "$VENTOY" remove ../a.iso --target "$STICK"
  [ "$status" -eq 1 ]
  run "$VENTOY" remove gone.iso -t "$STICK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not on the stick: gone.iso"* ]]
}

@test "isos: the catalogue, what is in the store, what is selected for the stick" {
  touch "$STORE/debian-13.iso" "$STORE/arch.iso"
  ln -s "$STORE/debian-13.iso" "$ISOS/debian-13.iso"
  run "$VENTOY" isos
  [ "${lines[0]}" = "debian"$'\t'"selected"$'\t'"-"$'\t'"debian-13.iso" ]
  [ "${lines[1]}" = "arch"$'\t'"downloaded"$'\t'"-"$'\t'"arch.iso" ]
  rm "$STORE/arch.iso"
  run env -u ANFS_TABLE "$VENTOY" isos --json
  [ "$output" = '[{"id":"debian","status":"selected","arch":null,"file":"debian-13.iso"},{"id":"arch","status":"missing","arch":null,"file":"arch.iso"}]' ]
  run "$VENTOY" __complete get ""
  [ "$output" = "arch"$'\n'"debian" ]
}

@test "get needs an id or --all, and knows its ids before it downloads" {
  run "$VENTOY" get
  [ "$status" -eq 64 ]
  run "$VENTOY" get nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown ISO 'nope'"* ]]
}

@test "get: an ISO already in the store is selected with a link, and sync copies the file" {
  echo debian > "$STORE/debian-13.iso"
  run "$VENTOY" get debian
  [ "$status" -eq 0 ]
  [ "$(readlink "$ISOS/debian-13.iso")" = "$STORE/debian-13.iso" ]
  run "$VENTOY" sync -y "$STICK"
  [ "$status" -eq 0 ]
  [ ! -L "$STICK/debian-13.iso" ]
  [ "$(cat "$STICK/debian-13.iso")" = debian ]
  run env -u ANFS_TABLE "$VENTOY" get debian --json
  [ "$output" = "{\"id\":\"debian\",\"file\":\"$STORE/debian-13.iso\"}" ]
}

@test "disks on Linux: usb disks only, from lsblk" {
  printf '#!/bin/sh\necho Linux\n' > "$BATS_TEST_TMPDIR/bin/uname"
  cat > "$BATS_TEST_TMPDIR/bin/lsblk" <<'EOF'
#!/bin/sh
case "$*" in
  *MOUNTPOINT*) [ "$3" = /dev/sdb ] && printf '\n/media/Ventoy\n' ;;
  *) echo 'NAME="/dev/sda" SIZE="1T" TRAN="sata" VENDOR="ATA     " MODEL="Disk"'
     echo 'NAME="/dev/sdb" SIZE="57.3G" TRAN="usb" VENDOR="SanDisk " MODEL="Ultra Fit"' ;;
esac
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/uname" "$BATS_TEST_TMPDIR/bin/lsblk"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$VENTOY" disks
  [ "$status" -eq 0 ]
  [ "$output" = "/dev/sdb"$'\t'"57.3G"$'\t'"-"$'\t'"-"$'\t'"/media/Ventoy"$'\t'"SanDisk Ultra Fit" ]
}

@test "the disk commands need Linux" {
  [[ "$(uname -s)" != Linux ]] || skip "this is Linux"
  run "$VENTOY" prepare /dev/nope
  [ "$status" -eq 69 ]
}

@test "a disk image as a target needs Linux" {
  [[ "$(uname -s)" != Linux ]] || skip "this is Linux"
  : > "$HOME/v.img"
  run "$VENTOY" list "$HOME/v.img"
  [ "$status" -eq 69 ]
  [[ "$output" == *"disk images need Linux (losetup)"* ]]
}

# Linux, with sudo running the stubs and losetup saying what $ATTACHED holds
linux_stubs() {
  printf '#!/bin/sh\necho Linux\n' > "$BATS_TEST_TMPDIR/bin/uname"
  printf '#!/bin/sh\nexec "$@"\n' > "$BATS_TEST_TMPDIR/bin/sudo"
  cat > "$BATS_TEST_TMPDIR/bin/losetup" <<'STUB'
#!/bin/sh
echo "losetup $*" >> "$HOME/losetup.log"
[ "$1" = -j ] && [ -n "$ATTACHED" ] && echo "$ATTACHED: []: ($2)"
exit 0
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin"/*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "prepare --size only sizes a new image" {
  linux_stubs
  : > "$HOME/v.img"
  run "$VENTOY" prepare "$HOME/v.img" --size 2G
  [ "$status" -eq 64 ]
  [[ "$output" == *"--size only sizes a new image"* ]]
  [ ! -e "$HOME/losetup.log" ]
}

@test "an image that is attached already is not attached a second time" {
  linux_stubs
  : > "$HOME/v.img"
  ATTACHED=/dev/loop7 run "$VENTOY" list "$HOME/v.img"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is already attached as /dev/loop7"* ]]
  [ "$(cat "$HOME/losetup.log")" = "losetup -j $HOME/v.img" ]
}
