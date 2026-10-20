#!/usr/bin/env bats
# ssh-key — offline: a temp HOME, ssh-keygen real, ssh-add a stub whose keys are the lines of
# $AGENT (none: it fails, as the real one does with an empty agent).
#
#   bats packages/ssh/tests/ssh-key.bats

bats_require_minimum_version 1.5.0

setup() {
  SSH_KEY="$BATS_TEST_DIRNAME/../home/.local/bin/ssh-key"
  local lib="${ANFS_TEST_LIB:-$HOME/.local/lib/anfs}"
  [[ -f "$lib/bash.sh" && -f "$lib/table.sh" ]] || skip "anfs's libraries are not installed at $lib"
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/lib" "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/keys"
  ln -s "$(cd "$lib" && pwd -P)" "$BATS_TEST_TMPDIR/home/.local/lib/anfs"
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME SSH_AUTH_SOCK ANFS_JSON ANFS_DEBUG
  export HOME ANFS_LOG=off ANFS_TABLE=tsv
  export AGENT="$BATS_TEST_TMPDIR/agent"
  : > "$AGENT"
  cat > "$BATS_TEST_TMPDIR/bin/ssh-add" <<'EOF'
#!/usr/bin/env bash
[ "$1" = -L ] || exit 2
[ -s "$AGENT" ] || { echo "The agent has no identities."; exit 1; }
cat "$AGENT"
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/ssh-add"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cd "$HOME"
}

# A key made elsewhere (the laptop the agent was forwarded from)
elsewhere() {
  ssh-keygen -q -t ed25519 -N "" -C "$1" -f "$BATS_TEST_TMPDIR/keys/$1" >/dev/null
  cat "$BATS_TEST_TMPDIR/keys/$1.pub"
}

fp() { ssh-keygen -lf "$1" | awk '{print $2}'; }

@test "list: no keys, nothing listed" {
  run "$SSH_KEY" list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ANFS_TABLE= run "$SSH_KEY" list --json
  [ "$output" = "[]" ]
}

@test "add makes ~/.ssh/id_ed25519 with no passphrase without a terminal; again does nothing" {
  run "$SSH_KEY" add </dev/null
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_ed25519" ] && [ -f "$HOME/.ssh/id_ed25519.pub" ]
  [ "$(stat -f %Lp "$HOME/.ssh" 2>/dev/null || stat -c %a "$HOME/.ssh")" = 700 ]
  [[ "$(cat "$HOME/.ssh/id_ed25519.pub")" == *" $(id -un)@$(hostname -s)" ]]
  ssh-keygen -y -P "" -f "$HOME/.ssh/id_ed25519" >/dev/null
  local before
  before=$(cat "$HOME/.ssh/id_ed25519.pub")

  run "$SSH_KEY" add --type rsa </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == "You have a key already: $(fp "$HOME/.ssh/id_ed25519.pub") (local ~/.ssh/id_ed25519.pub)" ]]
  [ ! -e "$HOME/.ssh/id_rsa" ]
  [ "$(cat "$HOME/.ssh/id_ed25519.pub")" = "$before" ]
}

@test "list shows a local key, and --json has its keys" {
  "$SSH_KEY" add </dev/null >/dev/null
  local f
  f=$(fp "$HOME/.ssh/id_ed25519.pub")
  run "$SSH_KEY" list
  [ "$output" = "$f	local	~/.ssh/id_ed25519.pub" ]
  ANFS_TABLE= run "$SSH_KEY" ls --json
  [ "$(yq -p json -r '.[0] | keys | join(" ")' <<< "$output")" = "key status file type comment public" ]
  [ "$(yq -p json -r '.[0].type' <<< "$output")" = ed25519 ]
  [ "$(yq -p json -r '.[0].file' <<< "$output")" = "$HOME/.ssh/id_ed25519.pub" ]
  [ "$(yq -p json -r '.[0].public' <<< "$output")" = "$(cat "$HOME/.ssh/id_ed25519.pub")" ]
}

@test "a .pub without its private key is not a key this machine can use" {
  mkdir -p "$HOME/.ssh"
  elsewhere laptop > "$HOME/.ssh/laptop.pub"
  run "$SSH_KEY" list
  [ -z "$output" ]
}

@test "an agent key is listed, once, and add then does nothing" {
  elsewhere laptop > "$AGENT"
  run "$SSH_KEY" list
  [ "$output" = "$(fp "$BATS_TEST_TMPDIR/keys/laptop.pub")	agent	-" ]
  run "$SSH_KEY" add </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == "You have a key already: "*" (agent)" ]]
  [ ! -e "$HOME/.ssh/id_ed25519" ]

  # A key both on disk and in the agent is one row: local
  mkdir -p "$HOME/.ssh"
  cp "$BATS_TEST_TMPDIR/keys/laptop" "$BATS_TEST_TMPDIR/keys/laptop.pub" "$HOME/.ssh/"
  run "$SSH_KEY" list
  [ "$(wc -l <<< "$output" | tr -d ' ')" = 1 ]
  [[ "$output" == *"	local	~/.ssh/laptop.pub" ]]
}

@test "public: the only key; with several, the one named; none is an error" {
  run "$SSH_KEY" public
  [ "$status" -eq 1 ]
  [[ "$output" == *"ssh-key add"* ]]

  "$SSH_KEY" add </dev/null >/dev/null
  run "$SSH_KEY" public
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$HOME/.ssh/id_ed25519.pub")" ]

  local agent
  agent=$(elsewhere laptop)
  echo "$agent" > "$AGENT"
  run "$SSH_KEY" public
  [ "$status" -eq 64 ]
  run "$SSH_KEY" public "$(fp "$BATS_TEST_TMPDIR/keys/laptop.pub")"
  [ "$output" = "$agent" ]
  run "$SSH_KEY" public SHA256:nope
  [ "$status" -eq 1 ]
}

@test "add --type is checked; completion offers the keys" {
  run "$SSH_KEY" add --type dsa </dev/null
  [ "$status" -eq 64 ]
  "$SSH_KEY" add </dev/null >/dev/null
  run "$SSH_KEY" __complete public ""
  [[ "$output" == "SHA256:"*"local ~/.ssh/id_ed25519.pub"* ]]
}
