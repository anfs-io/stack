#!/usr/bin/env bats
# git account — offline: a temp HOME, git's global config in it (GIT_CONFIG_GLOBAL), ssh-key from
# this clone's ssh package, ssh-keygen real. Stubs on PATH: curl serves https://<host>/<user>.keys
# from $ST/keys/<host>/<user> (none: 404; $ST/down: unreachable), gh is signed in when
# $ST/gh-login names someone, and ssh-add holds no keys.
#
#   bats packages/git/tests/account.bats

bats_require_minimum_version 1.5.0

setup() {
  local pkgs
  pkgs="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  ACCOUNT="$pkgs/git/home/.local/bin/git-account"
  local lib="${ANFS_TEST_LIB:-$HOME/.local/lib/anfs}"
  [[ -f "$lib/bash.sh" && -f "$lib/table.sh" ]] || skip "anfs's libraries are not installed at $lib"
  command -v yq >/dev/null || skip "yq is not installed"
  mkdir -p "$BATS_TEST_TMPDIR/home/.local/lib" "$BATS_TEST_TMPDIR/home/.local/bin" "$BATS_TEST_TMPDIR/bin"
  ln -s "$(cd "$lib" && pwd -P)" "$BATS_TEST_TMPDIR/home/.local/lib/anfs"
  ln -s "$pkgs/ssh/home/.local/bin/ssh-key" "$BATS_TEST_TMPDIR/home/.local/bin/ssh-key"
  HOME=$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME SSH_AUTH_SOCK GH_TOKEN ANFS_JSON ANFS_DEBUG
  export HOME ANFS_LOG=off ANFS_TABLE=tsv GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$HOME/gitconfig"
  export ST="$BATS_TEST_TMPDIR/st"
  mkdir -p "$ST/keys"
  : > "$ST/curl.log"; : > "$ST/gh.log"

  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
url="${!#}"
echo "$*" >> "$ST/curl.log"
[ ! -e "$ST/down" ] || { echo "curl: (28) timed out" >&2; exit 28; }
path="${url#https://}" host="${path%%/*}" user="${path#*/}" user="${user%.keys}"
if [ -f "$ST/keys/$host/$user" ]; then cat "$ST/keys/$host/$user"; printf '\n200'
else printf 'Not Found\n404'; fi
EOF
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$ST/gh.log"
case "$1 $2" in
  "auth status") [ -s "$ST/gh-login" ] || exit 1
                 echo "  - Token scopes: 'admin:public_key', 'repo'" ;;
  "api user") cat "$ST/gh-login" ;;
  "ssh-key add") cat >> "$ST/gh-added" ;;
  *) exit 1 ;;
esac
EOF
  cat > "$BATS_TEST_TMPDIR/bin/ssh-add" <<'EOF'
#!/usr/bin/env bash
echo "The agent has no identities."; exit 1
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin"/*
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cd "$HOME"
}

# The key here, made for the test
mykey() { ssh-keygen -q -t ed25519 -N "" -C me -f "$HOME/.ssh/id_ed25519" </dev/null >/dev/null; }
# <host> <user> has these keys: our own (mine), another's (other), or none
on_account() {
  local host="$1" user="$2"
  shift 2
  mkdir -p "$ST/keys/$host"
  : > "$ST/keys/$host/$user"
  for k in "$@"; do
    case "$k" in
      mine) awk '{print $1, $2}' "$HOME/.ssh/id_ed25519.pub" >> "$ST/keys/$host/$user" ;;
      other) rm -f "$ST/other" "$ST/other.pub"; ssh-keygen -q -t ed25519 -N "" -f "$ST/other" </dev/null >/dev/null
             awk '{print $1, $2}' "$ST/other.pub" >> "$ST/keys/$host/$user" ;;
    esac
  done
}
fp() { ssh-keygen -lf "$HOME/.ssh/id_ed25519.pub" | awk '{print $2}'; }

@test "add records account.github.com.user; the key on the account is said, and nothing else done" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account github.com octo mine
  run "$ACCOUNT" add --user octo </dev/null
  [ "$status" -eq 0 ]
  [ "$(git config --global account.github.com.user)" = octo ]
  [[ "$output" == *"Recorded github.com/octo"* ]]
  [[ "$output" == *"Your key $(fp) is on github.com"* ]]
  grep -q -- "--max-time 10 .*https://github.com/octo.keys" "$ST/curl.log"
  [ ! -s "$ST/gh.log" ]

  # A rerun with nothing new: nothing recorded again, exit 0
  run "$ACCOUNT" add </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *Recorded* ]]
  [[ "$output" == "Your key $(fp) is on github.com" ]]
}

@test "git account add: git runs it as a sub-command" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account gitlab.com ada mine
  PATH="${ACCOUNT%/*}:$PATH" run git account add --host gitlab.com --user ada </dev/null
  [ "$status" -eq 0 ]
  [ "$(git config --global account.gitlab.com.user)" = ada ]
}

@test "the key is not on the account and gh is not signed in: the key and the settings URL" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account github.com octo other
  run "$ACCOUNT" add --user octo </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"https://github.com/settings/ssh/new"* ]]
  [[ "$output" == *"$(cat "$HOME/.ssh/id_ed25519.pub")"* ]]
  [[ "$output" == *"then run this again"* ]]
  [[ "$output" == *"gh auth login"* ]]
  [ ! -e "$ST/gh-added" ]
}

@test "gitlab.com: its settings URL" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account gitlab.com ada
  run "$ACCOUNT" add --host gitlab.com --user ada </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"https://gitlab.com/-/user_settings/ssh_keys"* ]]
  [ ! -s "$ST/gh.log" ]
}

@test "gh signed in as the user: gh ssh-key add is given the key" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account github.com octo other
  echo octo > "$ST/gh-login"
  run "$ACCOUNT" add --user octo </dev/null
  [ "$status" -eq 0 ]
  grep -qx "ssh-key add - --title $(hostname -s)" "$ST/gh.log"
  [ "$(cat "$ST/gh-added")" = "$(cat "$HOME/.ssh/id_ed25519.pub")" ]
  [[ "$output" == *"Your key $(fp) is on github.com now"* ]]
}

@test "gh signed in as someone else: the key is printed, not added" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account github.com octo
  echo mallory > "$ST/gh-login"
  run "$ACCOUNT" add --user octo </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"signed in as mallory"* ]]
  [ ! -e "$ST/gh-added" ]
}

@test "no key here: ssh-key add makes one first, and -y is passed on" {
  on_account github.com octo
  echo octo > "$ST/gh-login"
  run "$ACCOUNT" add -y --user octo </dev/null
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_ed25519.pub" ]
  [[ "$output" == *"Made SHA256:"* ]]
  [ "$(cat "$ST/gh-added")" = "$(cat "$HOME/.ssh/id_ed25519.pub")" ]
}

@test "an unknown user (404) is an error naming the URL, and nothing is recorded" {
  run "$ACCOUNT" add --user nobody </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"https://github.com/nobody.keys"* ]]
  [ -z "$(git config --global account.github.com.user || true)" ]
}

@test "without --user and nothing recorded: a usage error" {
  run "$ACCOUNT" add </dev/null
  [ "$status" -eq 64 ]
  [[ "$output" == *"--user"* ]]
}

@test "a different user replaces the recorded one only when confirmed" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account github.com octo mine
  on_account github.com cat mine
  "$ACCOUNT" add --user octo </dev/null >/dev/null
  run "$ACCOUNT" add --user cat </dev/null
  [ "$status" -eq 77 ]
  [ "$(git config --global account.github.com.user)" = octo ]
  run "$ACCOUNT" add -y --user cat </dev/null
  [ "$status" -eq 0 ]
  [ "$(git config --global account.github.com.user)" = cat ]
}

@test "list: each account's status, and --json" {
  run "$ACCOUNT" list
  [ -z "$output" ]
  git config --global account.github.com.user octo
  git config --global account.gitlab.com.user ada
  on_account github.com octo other
  on_account gitlab.com ada
  run "$ACCOUNT" list
  [ "$output" = "github.com/octo	no key here	1
gitlab.com/ada	no key here	0" ]

  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account github.com octo mine other
  run "$ACCOUNT" ls
  [ "$output" = "github.com/octo	key on account	2
gitlab.com/ada	key not on account	0" ]

  ANFS_TABLE= run "$ACCOUNT" list --json
  [ "$(yq -p json -r '.[0] | keys | join(" ")' <<< "$output")" = "account status keys host user" ]
  [ "$(yq -p json -r '.[1].status' <<< "$output")" = "key not on account" ]

  touch "$ST/down"
  run "$ACCOUNT" list
  [ "$output" = "github.com/octo	unreachable	-
gitlab.com/ada	unreachable	-" ]
}

@test "remove asks (77 without a terminal), and with -y forgets the account; the keys stay" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  git config --global account.github.com.user octo
  run "$ACCOUNT" remove github.com </dev/null
  [ "$status" -eq 77 ]
  [ "$(git config --global account.github.com.user)" = octo ]
  run "$ACCOUNT" rm -y github.com </dev/null
  [ "$status" -eq 0 ]
  [ -z "$(git config --global account.github.com.user || true)" ]
  [ -f "$HOME/.ssh/id_ed25519" ]
  run "$ACCOUNT" rm -y github.com </dev/null
  [ "$status" -eq 1 ]
}

@test "-i asks for the host, then the user; the recorded user is the default" {
  mkdir -m 700 "$HOME/.ssh"
  mykey
  on_account gitlab.com ada mine
  ANFS_TEST_TERMINAL=1 run "$ACCOUNT" add -i < <(printf 'gitlab.com\nada\n')
  [ "$status" -eq 0 ]
  [[ "$output" == *"git host"*"user name"* ]]
  [ "$(git config --global account.gitlab.com.user)" = ada ]

  # Again: Enter takes the host recorded (the only one) and its user
  ANFS_TEST_TERMINAL=1 run "$ACCOUNT" add -i < <(printf '\n\n')
  [ "$status" -eq 0 ]
  [[ "$output" == *"[ada]"* ]]
  [[ "$output" == *"Your key $(fp) is on gitlab.com"* ]]
}

@test "-i without a terminal: 77" {
  run "$ACCOUNT" add -i </dev/null
  [ "$status" -eq 77 ]
}
