#!/usr/bin/env bats
# remotefs — offline: a temp HOME, and every program it drives is a stub on PATH. `sshfs` records
# its arguments and adds the mountpoint to $MOUNTED, which is what the stubbed mount table
# (findmnt on Linux, mount on macOS) reads; `ssh` and `df` answer as $SSH_RC and $DF_RC say.
#
#   bats packages/remotefs/tests/remotefs.bats

setup() {
  RFS="$BATS_TEST_DIRNAME/../home/.local/bin/remotefs"
  local lib="${ANFS_TEST_LIB:-$HOME/.local/lib/anfs}"
  [[ -f "$lib/bash.sh" && -f "$lib/table.sh" ]] || skip "anfs's libraries are not installed at $lib"
  command -v yq >/dev/null || skip "yq is not installed"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/lib" "$BIN"
  ln -s "$(cd "$lib" && pwd -P)" "$BATS_TEST_TMPDIR/home/.local/lib/anfs"
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
  XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
  unset REMOTEFS_CONFIG REMOTEFS_MOUNT_HOME REMOTEFS_DEFAULT_OPTIONS REMOTEFS_SSHFS ANFS_DEBUG ANFS_JSON
  unset REMOTEFS_CONFIG_HOME REMOTEFS_DATA_HOME REMOTEFS_STATE_HOME REMOTEFS_CACHE_HOME
  export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  export ANFS_LOG=off ANFS_TABLE=tsv REMOTEFS_MOUNT_TIMEOUT=2 REMOTEFS_STAT_TIMEOUT=1
  export MOUNTED="$BATS_TEST_TMPDIR/mounted" ARGV="$BATS_TEST_TMPDIR/argv" OS=Linux
  : > "$MOUNTED"; : > "$ARGV"
  CONFIG="$XDG_CONFIG_HOME/remotefs/mounts.yml"

  stub uname 'echo "$OS"'
  stub ssh 'echo "ssh $*" >> "$ARGV"; [ "${SSH_RC:-0}" = 0 ] || echo "Permission denied (publickey)." >&2; exit "${SSH_RC:-0}"'
  stub df 'exit "${DF_RC:-0}"'
  stub sshfs 'echo "sshfs $*" >> "$ARGV"
[ -z "${SSHFS_HANG:-}" ] || exec sleep 30
[ "${SSHFS_RC:-0}" = 0 ] || exit "$SSHFS_RC"
echo "$2" >> "$MOUNTED"'
  stub findmnt 'grep -qxF "$3" "$MOUNTED"'
  stub mount 'while read -r p; do echo "fuse-t:/x on $p (nfs, nodev)"; done < "$MOUNTED"'
  local un='[ "${UMOUNT_RC:-0}" = 0 ] || { echo "umount: $p: Resource busy" >&2; exit "$UMOUNT_RC"; }
echo "$0 $*" >> "$ARGV"
grep -vxF "$p" "$MOUNTED" > "$MOUNTED.tmp"; mv "$MOUNTED.tmp" "$MOUNTED"'
  stub fusermount3 'for p; do :; done'"
$un"
  stub umount 'for p; do :; done'"
$un"
  PATH="$BIN:$PATH"
  cd "$HOME"
}

# A stub on PATH: <name> <sh body>
stub() {
  printf '#!/bin/sh\n%s\n' "$2" > "$BIN/$1"
  chmod +x "$BIN/$1"
}

@test "help lists the commands, and an unknown one is a usage error" {
  run "$RFS" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"mount, up [-a] [label...]"* ]]
  run "$RFS" bogus
  [ "$status" -eq 64 ]
}

@test "add: the label is the host, the mountpoint is ~/mnt/<label>" {
  run "$RFS" add web1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Added web1: web1: at ~/mnt/web1"* ]]
  run "$RFS" list
  [ "$output" = "web1"$'\t'"web1:"$'\t'"~/mnt/web1"$'\t'"unmounted" ]
  run env -u ANFS_TABLE "$RFS" ls --json
  [ "$output" = "[{\"label\":\"web1\",\"remote\":\"web1:\",\"mountpoint\":\"$HOME/mnt/web1\",\"state\":\"unmounted\"}]" ]
}

@test "add: a remote, a mountpoint kept with its ~, options, no defaults" {
  run "$RFS" add web1-logs web1:/var/log "$HOME/logs" -o ro -o Port=2222 --no-defaults
  [ "$status" -eq 0 ]
  [ "$(yq -r '.web1-logs.mountpoint' "$CONFIG")" = "~/logs" ]
  run "$RFS" show web1-logs
  [[ "$output" == *"options:     ro Port=2222"* ]]
  [[ "$output" == *"command:     sshfs web1:/var/log $HOME/logs -o ro -o Port=2222"* ]]
}

@test "add refuses a label that exists, one that is not a label, a remote that is not one" {
  "$RFS" add web1
  run "$RFS" add web1
  [ "$status" -eq 73 ]
  run "$RFS" add Web/1
  [ "$status" -eq 64 ]
  run "$RFS" add web2 nocolon
  [ "$status" -eq 64 ]
}

@test "mount: checks ssh first, then sshfs with the reconnect options" {
  "$RFS" add web1 admin@web1:/srv -o Port=2222 -o ro
  run "$RFS" mount web1
  [ "$status" -eq 0 ]
  [[ "$output" == *"web1: mounted admin@web1:/srv at ~/mnt/web1"* ]]
  [ "$(sed -n 1p "$ARGV")" = "ssh -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o Port=2222 admin@web1 true" ]
  [ "$(sed -n 2p "$ARGV")" = "sshfs admin@web1:/srv $HOME/mnt/web1 -o reconnect -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o Port=2222 -o ro" ]
  run "$RFS" list
  [[ "$output" == *$'\t'"mounted" ]]
  run "$RFS" up web1
  [[ "$output" == *"already mounted"* ]]
  [ "$(grep -c '^sshfs' "$ARGV")" -eq 1 ]
}

@test "mount: a host that cannot be logged in to never reaches sshfs" {
  "$RFS" add web1
  SSH_RC=255 run "$RFS" mount web1
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot log in to web1 over ssh: Permission denied"* ]]
  ! grep -q '^sshfs' "$ARGV"
  [ ! -d "$HOME/mnt/web1" ]
}

@test "mount: sshfs failing, or never returning, is an error and leaves no directory" {
  "$RFS" add web1
  SSHFS_RC=1 run "$RFS" mount web1
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not mount web1:"* ]]
  SSHFS_HANG=1 run "$RFS" mount web1
  [ "$status" -eq 1 ]
  [[ "$output" == *"did not finish mounting within 2s"* ]]
  [ ! -d "$HOME/mnt/web1" ]
}

@test "mount --all: one that fails does not stop the rest" {
  "$RFS" add web1
  "$RFS" add web2
  stub ssh 'case "$*" in *web1*) exit 255 ;; esac'
  run "$RFS" mount --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"web2: mounted"* ]]
  run "$RFS" mount
  [ "$status" -eq 64 ]
}

@test "stale: mounted but not answering; mount says so, umount clears it" {
  "$RFS" add web1
  "$RFS" mount web1
  DF_RC=1 run "$RFS" list
  [[ "$output" == *$'\t'"stale" ]]
  DF_RC=1 run "$RFS" mount web1
  [ "$status" -eq 1 ]
  [[ "$output" == *"not answering"* ]]
  DF_RC=1 run "$RFS" umount web1
  [ "$status" -eq 0 ]
  run "$RFS" list
  [[ "$output" == *$'\t'"unmounted" ]]
}

@test "umount: fusermount3 on Linux, -z with --force, and the default mountpoint goes" {
  "$RFS" add web1
  "$RFS" mount web1
  UMOUNT_RC=1 run "$RFS" umount web1
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not unmount ~/mnt/web1: Resource busy (-f to force)"* ]]
  run "$RFS" down web1 -f
  [ "$status" -eq 0 ]
  grep -q "fusermount3 -uz $HOME/mnt/web1" "$ARGV"
  [ ! -d "$HOME/mnt/web1" ]
  run "$RFS" umount web1
  [ "$status" -eq 1 ]
  [[ "$output" == *"not mounted"* ]]
}

@test "macOS: the volume is named after the label, and umount is umount" {
  export OS=Darwin
  "$RFS" add web1
  run "$RFS" mount web1
  [ "$status" -eq 0 ]
  grep -q -- "-o volname=web1" "$ARGV"
  run "$RFS" list
  [[ "$output" == *$'\t'"mounted" ]]
  run "$RFS" umount --all
  [ "$status" -eq 0 ]
  grep -q "umount $HOME/mnt/web1" "$ARGV"
}

@test "remove: refused while mounted, unless forced" {
  "$RFS" add web1
  "$RFS" mount web1
  run "$RFS" remove web1
  [ "$status" -eq 1 ]
  [[ "$output" == *"is mounted"* ]]
  run "$RFS" rm -f web1
  [ "$status" -eq 0 ]
  [ ! -s "$MOUNTED" ]
  run "$RFS" path web1
  [ "$status" -eq 1 ]
}

@test "path and completion" {
  "$RFS" add web1
  "$RFS" add web1-logs web1:/var/log
  run "$RFS" path web1-logs
  [ "$output" = "$HOME/mnt/web1-logs" ]
  run "$RFS" __complete mount ""
  [ "$output" = "web1"$'\n'"web1-logs" ]
}

@test "path with no label is where mounts go" {
  run "$RFS" path
  [ "$output" = "$HOME/mnt" ]
}

@test "--json: what a command did, one object per label, and nothing else" {
  run env -u ANFS_TABLE "$RFS" add web1 --json
  [ "$output" = "{\"label\":\"web1\",\"remote\":\"web1:\",\"mountpoint\":\"$HOME/mnt/web1\"}" ]
  "$RFS" add web2
  run "$RFS" mount --all --json
  [ "${lines[0]}" = "{\"label\":\"web1\",\"mountpoint\":\"$HOME/mnt/web1\",\"state\":\"mounted\"}" ]
  [ "${lines[1]}" = "{\"label\":\"web2\",\"mountpoint\":\"$HOME/mnt/web2\",\"state\":\"mounted\"}" ]
  [ "${#lines[@]}" -eq 2 ]
  run "$RFS" umount web1 --json
  [ "$output" = "{\"label\":\"web1\",\"mountpoint\":\"$HOME/mnt/web1\",\"state\":\"unmounted\"}" ]
  run "$RFS" remove web2 -f --json
  [ "$output" = "{\"label\":\"web2\",\"removed\":\"true\"}" ]
}

@test "cd: the shell function mounts and changes directory; the command alone cannot" {
  run "$RFS" cd web1
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires the remotefs shell function"* ]]
  "$RFS" add web1
  ln -s "$RFS" "$BIN/remotefs"
  # The stubbed sshfs mounts nothing, so the mountpoint is the empty directory mount made
  run bash -c "source '$BATS_TEST_DIRNAME/../home/.config/sh/remotefs.sh'; remotefs cd web1 && pwd; remotefs cd && pwd"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$HOME/mnt/web1" ]
  [ "${lines[1]}" = "$HOME/mnt" ]
  grep -qxF "$HOME/mnt/web1" "$MOUNTED"
}
