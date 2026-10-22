#!/usr/bin/env bats
# ventoy — offline: a temp HOME (the ISO store with it), the stick is a directory, nothing is
# mounted, and a download is a stubbed `curl`.
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

# curl: writes "from <url>" where -o says (the downloader's only use of it here)
curl_stub() {
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
out="" url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w|--retry|-C) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
echo "from $url" > "$out"
printf 200
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
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
  [ "$status" -eq 77 ]
  [[ "$output" == *"pass -y"* ]]
  [ -f "$STICK/extra.iso" ]
  run "$VENTOY" sync "$STICK" -y </dev/null
  [ "$status" -eq 0 ]
  [ ! -f "$STICK/extra.iso" ] && [ -f "$STICK/new.iso" ]
}

@test "remove takes rm and --target, asks first, and refuses a path off the stick" {
  printf 'aaaa' > "$STICK/a.iso"
  run "$VENTOY" rm a.iso -t "$STICK" </dev/null
  [ "$status" -eq 77 ]
  [ -f "$STICK/a.iso" ]
  run "$VENTOY" rm -y a.iso -t "$STICK"
  [ "$status" -eq 0 ]
  [ ! -f "$STICK/a.iso" ]
  run "$VENTOY" remove -y ../a.iso --target "$STICK"
  [ "$status" -eq 1 ]
  run "$VENTOY" remove -y gone.iso -t "$STICK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not on the stick: gone.iso"* ]]
}

@test "isos and get are gone: the iso group replaces them" {
  run "$VENTOY" isos
  [ "$status" -eq 64 ]
  run "$VENTOY" get debian
  [ "$status" -eq 64 ]
  run "$VENTOY" iso
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ventoy iso <list|show|pull|add|remove|path|prune>"* ]]
}

@test "iso list: the catalogue and the store, the same rows as anfs iso list" {
  touch "$STORE/debian-13.iso" "$STORE/stray.iso"
  echo sum > "$STORE/debian-13.iso.sha256"
  run "$VENTOY" iso list --all
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "debian"$'\t'"present"$'\t'"-"$'\t'"-"$'\t'"debian-13.iso"$'\t'"0B" ]
  [ "${lines[1]}" = "arch"$'\t'"missing"$'\t'"-"$'\t'"-"$'\t'"arch.iso"$'\t'"-" ]
  [ "${lines[2]}" = "-"$'\t'"unlisted"$'\t'"-"$'\t'"-"$'\t'"stray.iso"$'\t'"0B" ]
  local rows="$output" anfs="$HOME/.local/lib/anfs/../../bin/anfs"
  run "$VENTOY" __complete copy ""
  [ "$output" = "debian"$'\n'"arch" ]
  run "$VENTOY" __complete iso pull ""
  [ "$output" = "debian"$'\n'"arch" ]
  [[ -x "$anfs" ]] || skip "no anfs beside the libraries to compare with"
  run "$anfs" iso list --all
  [ "$output" = "$rows" ]
}

@test "iso pull downloads into the store, and iso remove deletes from it" {
  curl_stub
  run "$VENTOY" iso pull arch
  [ "$status" -eq 0 ]
  [ "$(cat "$STORE/arch.iso")" = "from https://example.invalid/arch.iso" ]
  [ ! -e "$ISOS/arch.iso" ]
  run "$VENTOY" iso rm -y arch
  [ "$status" -eq 0 ]
  [ ! -e "$STORE/arch.iso" ]
}

@test "copy knows its ids before it downloads, and its stick is --target" {
  run "$VENTOY" copy nope -t "$STICK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no ISO 'nope' in the catalogue"* ]]
  run "$VENTOY" copy "$STICK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"the stick is --target"* ]]
}

@test "copy <iso>: an ISO in the store is selected with a link, and the file is copied" {
  echo debian > "$STORE/debian-13.iso"
  printf 'aaaa' > "$ISOS/other.iso"
  run "$VENTOY" copy debian -t "$STICK"
  [ "$status" -eq 0 ]
  [ "$(readlink "$ISOS/debian-13.iso")" = "$STORE/debian-13.iso" ]
  [ ! -L "$STICK/debian-13.iso" ]
  [ "$(cat "$STICK/debian-13.iso")" = debian ]
  # only what was named; the rest of the selection goes with a plain copy
  [ ! -e "$STICK/other.iso" ]
  run "$VENTOY" copy --target "$STICK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping debian-13.iso"* ]]
  [ -f "$STICK/other.iso" ]
}

@test "copy <iso> pulls an ISO the store does not have" {
  curl_stub
  run "$VENTOY" copy arch -t "$STICK"
  [ "$status" -eq 0 ]
  [ "$(cat "$STORE/arch.iso")" = "from https://example.invalid/arch.iso" ]
  [ "$(cat "$STICK/arch.iso")" = "from https://example.invalid/arch.iso" ]
}

@test "copy <iso>: a newer version replaces the one selected before, unless --keep" {
  echo 13 > "$STORE/debian-13.iso"; echo 14 > "$STORE/debian-14.iso"; echo 15 > "$STORE/debian-15.iso"
  "$VENTOY" copy debian -t "$STICK"
  sed -i.bak 's/debian-13.iso/debian-14.iso/' "$XDG_CONFIG_HOME/anfs/isos.yml"
  run "$VENTOY" copy debian -t "$STICK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed older debian-13.iso"* ]]
  [ -L "$ISOS/debian-14.iso" ] && [ ! -e "$ISOS/debian-13.iso" ]
  [ -f "$STORE/debian-13.iso" ]
  sed -i.bak 's/debian-14.iso/debian-15.iso/' "$XDG_CONFIG_HOME/anfs/isos.yml"
  run "$VENTOY" copy -k debian -t "$STICK"
  [ -L "$ISOS/debian-15.iso" ] && [ -L "$ISOS/debian-14.iso" ]
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

@test "ventoy config: list, set and get on a temp home (core's lib/anfs/config.sh)" {
  [[ -f "$HOME/.local/lib/anfs/config.sh" ]] || skip "this core's lib/anfs has no config.sh"
  mkdir -p "$XDG_CONFIG_HOME/ventoy"
  cp "$BATS_TEST_DIRNAME/../home/.config/ventoy/ventoy.env" "$XDG_CONFIG_HOME/ventoy/"
  run "$VENTOY" config list
  [ "$status" -eq 0 ]
  [[ "$output" == *"VENTOY_IMAGE_SIZE"$'\t'"64G"$'\t'"default"* ]]
  run "$VENTOY" config set VENTOY_IMAGE_SIZE=32G
  [ "$status" -eq 0 ]
  grep -qx "VENTOY_IMAGE_SIZE=32G" "$XDG_CONFIG_HOME/ventoy/ventoy.local.env"
  run "$VENTOY" config get VENTOY_IMAGE_SIZE
  [ "$output" = "32G" ]
}
