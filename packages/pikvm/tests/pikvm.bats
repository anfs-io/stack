#!/usr/bin/env bats
# pikvm — offline: a temp HOME, and `ssh` is a stub that plays the PiKVM. Its root filesystem
# mode is the file $FS, its drive ("<connected> <image>") the file $MSD; every remote command is
# a line of $ARGV.
#
#   bats packages/pikvm/tests/pikvm.bats

setup() {
  PIKVM="$BATS_TEST_DIRNAME/../home/.local/bin/pikvm"
  local lib="${ANFS_TEST_LIB:-$HOME/.local/lib/anfs}"
  [[ -f "$lib/bash.sh" && -f "$lib/table.sh" ]] || skip "anfs's libraries are not installed at $lib"
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/lib" "$BATS_TEST_TMPDIR/home/.ssh" "$BATS_TEST_TMPDIR/bin"
  ln -s "$(cd "$lib" && pwd -P)" "$BATS_TEST_TMPDIR/home/.local/lib/anfs"
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
  XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
  unset PIKVM_HOST PIKVM_SSH_OPTS PIKVM_MSD_IMAGE ANFS_DEBUG ANFS_JSON
  export HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  export ANFS_LOG=off ANFS_TABLE=tsv
  export ARGV="$BATS_TEST_TMPDIR/argv" FS="$BATS_TEST_TMPDIR/fs" MSD="$BATS_TEST_TMPDIR/msd"
  echo ro > "$FS"
  echo "0 -" > "$MSD"
  : > "$ARGV"

  cat > "$BATS_TEST_TMPDIR/bin/ssh" <<'EOF'
#!/usr/bin/env bash
master=0 ctl=0
while [[ $# -gt 0 && "$1" == -* ]]; do
  case "$1" in
    -fNM) master=1; shift ;;
    -O) ctl=1; shift 2 ;;
    -o|-p|-i) shift 2 ;;
    *) shift ;;
  esac
done
host="$1"; shift
if [[ $master == 1 ]]; then echo "connect $host" >> "$ARGV"; exit "${SSH_RC:-0}"; fi
[[ $ctl == 0 ]] || exit 0
cmd="$*"
case "$cmd" in
  python3*) echo "$host: api ${cmd##*\' }" >> "$ARGV" ;;
  *) echo "$host: $cmd" >> "$ARGV" ;;
esac
case "$cmd" in
  hostname) echo kvm1 ;;
  "findmnt -no OPTIONS /") echo "$(cat "$FS"),relatime" ;;
  rw|ro) [[ "$cmd" != "${FAIL_MODE:-}" ]] || exit 1; echo "$cmd" > "$FS" ;;
  *" state GET msd") cat "$MSD" ;;
  *" fields GET msd")
    read -r c i < "$MSD"
    [[ $c == 1 ]] && c=true || c=false
    printf 'true\tfalse\t%s\t%s\tfalse\tfalse\n' "$i" "$c" ;;
  *" images GET msd") printf '64.0G\tventoy/ventoy.img\n1.2G\tdebian.iso\n' ;;
  *"msd/set_params image="*) i="${cmd##*image=}"; echo "${i%% *}" > "$MSD.sel" ;;
  *"connected=1") echo "1 $(cat "$MSD.sel")" > "$MSD" ;;
  *"connected=0") read -r _ i < "$MSD"; echo "0 $i" > "$MSD" ;;
  "false") exit 3 ;;
esac
EOF
  cat > "$BATS_TEST_TMPDIR/bin/ssh-copy-id" <<'EOF'
#!/usr/bin/env bash
echo "ssh-copy-id fs=$(cat "$FS"): $*" | sed 's|ControlPath=[^ ]*|ControlPath=CTL|' >> "$ARGV"
EOF
  cat > "$BATS_TEST_TMPDIR/bin/ssh-add" <<'EOF'
#!/usr/bin/env bash
exit "${AGENT_RC:-0}"
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin"/*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cd "$HOME"
}

@test "help lists the commands and needs no connection; an unknown one is a usage error" {
  run "$PIKVM" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"copy-id"* && "$output" == *"msd"* && "$output" == *"PIKVM_MSD_IMAGE"* ]]
  run "$PIKVM" msd
  [ "$status" -eq 0 ]
  [[ "$output" == *"connect [-H HOST] [image]"* ]]
  run "$PIKVM" bogus
  [ "$status" -eq 64 ]
  run "$PIKVM" status --bogus
  [ "$status" -eq 64 ]
  [ ! -s "$ARGV" ]
}

@test "status: one connection, the default host, and --json" {
  run "$PIKVM" status
  [ "$status" -eq 0 ]
  [ "$output" = "kvm1  root filesystem: ro" ]
  [ "$(sed -n 1p "$ARGV")" = "connect root@pikvm" ]
  [ "$(grep -c '^connect' "$ARGV")" -eq 1 ]
  run "$PIKVM" status --json
  [ "$output" = '{"host":"root@pikvm","hostname":"kvm1","root":"ro"}' ]
}

@test "the host comes from -H, else PIKVM_HOST" {
  PIKVM_HOST=admin@kvm2 run "$PIKVM" status
  [ "$(sed -n 1p "$ARGV")" = "connect admin@kvm2" ]
  PIKVM_HOST=admin@kvm2 run "$PIKVM" status -H kvm3
  grep -qx "connect kvm3" "$ARGV"
}

@test "PIKVM_HOST from pikvm.local.env, over pikvm.env; the environment wins" {
  mkdir -p "$XDG_CONFIG_HOME/pikvm"
  printf '#PIKVM_HOST=root@pikvm\nPIKVM_HOST=shipped@kvm\n' > "$XDG_CONFIG_HOME/pikvm/pikvm.env"
  printf 'PIKVM_HOST=local@kvm\n' > "$XDG_CONFIG_HOME/pikvm/pikvm.local.env"
  run "$PIKVM" status
  [ "$(sed -n 1p "$ARGV")" = "connect local@kvm" ]
  : > "$ARGV"
  rm "$XDG_CONFIG_HOME/pikvm/pikvm.local.env"
  run "$PIKVM" status
  [ "$(sed -n 1p "$ARGV")" = "connect shipped@kvm" ]
  : > "$ARGV"
  PIKVM_HOST=env@kvm run "$PIKVM" status
  [ "$(sed -n 1p "$ARGV")" = "connect env@kvm" ]
}

@test "a PiKVM that cannot be reached fails before anything runs" {
  SSH_RC=255 run "$PIKVM" status
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot connect to root@pikvm"* ]]
  ! grep -q "hostname" "$ARGV"
}

@test "run: the command goes over as typed, its exit status comes back" {
  run "$PIKVM" run -- ls -la /etc/kvmd
  [ "$status" -eq 0 ]
  grep -qx "root@pikvm: ls -la /etc/kvmd" "$ARGV"
  ! grep -qx "root@pikvm: rw" "$ARGV"
  run "$PIKVM" run false
  [ "$status" -eq 3 ]
  run "$PIKVM" run
  [ "$status" -eq 64 ]
}

@test "run -w: read/write for the command, read-only again after, also when it fails" {
  run "$PIKVM" run -w false
  [ "$status" -eq 3 ]
  [ "$(grep -n -x 'root@pikvm: \(rw\|false\|ro\)' "$ARGV" | cut -d' ' -f2 | tr '\n' ' ')" = "rw false ro " ]
  [ "$(cat "$FS")" = ro ]
}

@test "run -w leaves a filesystem that was read/write already as it was" {
  echo rw > "$FS"
  run "$PIKVM" run -w -- touch /etc/x
  [ "$status" -eq 0 ]
  ! grep -qx "root@pikvm: ro" "$ARGV"
  [ "$(cat "$FS")" = rw ]
}

@test "run -w: failing to go back to read-only is an error" {
  FAIL_MODE=ro run "$PIKVM" run -w -- touch /etc/x
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to switch root@pikvm back to read-only"* ]]
}

@test "rw and ro switch the filesystem and stay there" {
  run "$PIKVM" rw
  [ "$status" -eq 0 ]
  [ "$(cat "$FS")" = rw ]
  run "$PIKVM" ro --json
  [ "$output" = '{"host":"root@pikvm","root":"ro"}' ]
  [ "$(cat "$FS")" = ro ]
}

@test "copy-id: the agent's keys over the shared connection, inside rw/ro" {
  run "$PIKVM" copy-id
  [ "$status" -eq 0 ]
  grep -qx "ssh-copy-id fs=rw: -o ControlPath=CTL root@pikvm" "$ARGV"
  [ "$(cat "$FS")" = ro ]
}

@test "copy-id: --identity a key file, -f; no agent keys and an unreadable file are refused" {
  echo key > "$HOME/id.pub"
  PIKVM_SSH_OPTS="-p 2222" run "$PIKVM" copy-id -f --identity "$HOME/id.pub"
  [ "$status" -eq 0 ]
  grep -qx "ssh-copy-id fs=rw: -o ControlPath=CTL -p 2222 -i $HOME/id.pub -f root@pikvm" "$ARGV"
  AGENT_RC=1 run "$PIKVM" copy-id
  [ "$status" -eq 1 ]
  [[ "$output" == *"ssh-agent has no keys"* ]]
  run "$PIKVM" copy-id --identity "$HOME/nope.pub"
  [ "$status" -eq 1 ]
  # -i is every tool's --interactive, not --identity
  run "$PIKVM" copy-id -i "$HOME/id.pub" < /dev/null
  [ "$status" -eq 77 ]
  [ "$(cat "$FS")" = ro ]
}

@test "msd status and msd list, and their --json" {
  echo "1 ventoy/ventoy.img" > "$MSD"
  run "$PIKVM" msd status
  [ "$status" -eq 0 ]
  [[ "$output" == *"image:     ventoy/ventoy.img"* ]]
  [[ "$output" == *"connected: true   cdrom: false   rw: false"* ]]
  run "$PIKVM" msd status --json
  [ "$output" = '{"host":"root@pikvm","online":"true","busy":"false","image":"ventoy/ventoy.img","connected":"true","cdrom":"false","rw":"false"}' ]
  run "$PIKVM" msd ls
  [ "${lines[0]}" = "64.0G"$'\t'"ventoy/ventoy.img" ]
  run env -u ANFS_TABLE "$PIKVM" msd list --json
  [ "$output" = '[{"size":"64.0G","image":"ventoy/ventoy.img"},{"size":"1.2G","image":"debian.iso"}]' ]
}

@test "msd connect: the default image as a read-only flash drive; again is a no-op" {
  run "$PIKVM" msd connect
  [ "$status" -eq 0 ]
  [ "$output" = "Connected ventoy/ventoy.img (flash, read-only)" ]
  grep -qx "root@pikvm: api none POST msd/set_params image=ventoy/ventoy.img cdrom=0 rw=0" "$ARGV"
  [ "$(cat "$MSD")" = "1 ventoy/ventoy.img" ]
  run "$PIKVM" msd connect
  [ "$output" = "Already connected: ventoy/ventoy.img" ]
}

@test "msd connect another image disconnects the current one first" {
  echo "1 ventoy/ventoy.img" > "$MSD"
  run "$PIKVM" msd connect debian.iso
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Disconnected ventoy/ventoy.img" ]
  [ "${lines[1]}" = "Connected debian.iso (flash, read-only)" ]
  run "$PIKVM" msd disconnect --json
  [ "$output" = '{"host":"root@pikvm","image":"debian.iso","connected":"false"}' ]
  run "$PIKVM" msd disconnect
  [ "$output" = "Not connected" ]
}

@test "msd with: disconnected around a local command, reconnected even when it fails" {
  echo "1 ventoy/ventoy.img" > "$MSD"
  run "$PIKVM" msd with -- sh -c 'cat "$MSD"; exit 7'
  [ "$status" -eq 7 ]
  [ "${lines[1]}" = "0 ventoy/ventoy.img" ]
  [ "$(cat "$MSD")" = "1 ventoy/ventoy.img" ]
}

@test "msd with: a drive that was not connected stays that way" {
  run "$PIKVM" msd with -- true
  [ "$status" -eq 0 ]
  [ "$(cat "$MSD")" = "0 -" ]
  run "$PIKVM" msd with
  [ "$status" -eq 64 ]
}

@test "completion: commands, msd's sub-commands, ssh hosts for -H" {
  printf 'Host kvm1 kvm2\nHost *\n  User root\n' > "$HOME/.ssh/config"
  run "$PIKVM" __complete ""
  [[ "$output" == *"copy-id"* && "$output" == *"msd"* ]]
  run "$PIKVM" __complete msd ""
  [[ "$output" == *"connect"* && "$output" == *"with"* ]]
  run "$PIKVM" __complete status -H ""
  [ "$output" = "kvm1"$'\n'"kvm2" ]
}

@test "pikvm config: list, set and get on a temp home (core's lib/anfs/config.sh)" {
  [[ -f "$HOME/.local/lib/anfs/config.sh" ]] || skip "this core's lib/anfs has no config.sh"
  mkdir -p "$XDG_CONFIG_HOME/pikvm"
  cp "$BATS_TEST_DIRNAME/../home/.config/pikvm/pikvm.env" "$XDG_CONFIG_HOME/pikvm/"
  run "$PIKVM" config list
  [ "$status" -eq 0 ]
  [[ "$output" == *"PIKVM_HOST"$'\t'"root@pikvm"$'\t'"default"* ]]
  run "$PIKVM" config set PIKVM_HOST=root@kvm2
  [ "$status" -eq 0 ]
  grep -qx "PIKVM_HOST=root@kvm2" "$XDG_CONFIG_HOME/pikvm/pikvm.local.env"
  run "$PIKVM" config get PIKVM_HOST
  [ "$output" = "root@kvm2" ]
}
