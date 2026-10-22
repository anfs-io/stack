#!/usr/bin/env bats
# The steps stack/git, stack/ssh and stack/op bring to `anfs onboard`: one walk through all of
# them, since each reads what the others found (the key, the vault, who you are on GitHub).
# The real anfs and ppm commands run in a temp $HOME with this clone as the stack source; gh, op
# and ssh-add are stubbed, and `ppm install` / `ppm file add` only do what stow would. No network.
# Needs the anfs repo beside this one (sources/core or sources/anfs), or $ANFS_REPO.
# Run: bats packages/git/tests/onboard.bats

unset ANFS_WORK ANFS_WORK_SAID  # a person's ANFS_WORK never reaches a test (lib/anfs/work.sh)

bats_require_minimum_version 1.5.0

setup() {
  local stack tools="$BATS_TEST_TMPDIR/tools" t repo=""
  stack="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  for t in "${ANFS_REPO:-}" "$stack/../core" "$stack/../anfs"; do
    [[ -n "$t" && -x "$t/packages/anfs/home/.local/bin/anfs" ]] && { repo="$(cd "$t" && pwd)"; break; }
  done
  [[ -n "$repo" ]] || skip "the anfs repo is not beside this one (set ANFS_REPO)"
  ANFS="$repo/packages/anfs/home/.local/bin/anfs"

  export HOME="$BATS_TEST_TMPDIR/home"
  STUBS="$HOME/stubs" ST="$HOME/stub-state"
  SOURCES="$HOME/.local/share/anfs/sources"
  INSTALLED="$HOME/.local/state/ppm/installed"
  mkdir -p "$HOME/.local/lib" "$HOME/.local/bin" "$HOME/.config/anfs" "$STUBS" "$ST" "$tools" "$SOURCES" "$INSTALLED/stack"
  ln -s "$repo/packages/anfs/home/.local/lib/anfs" "$HOME/.local/lib/anfs"
  ln -s "$repo/packages/ppm/home/.local/lib/ppm" "$HOME/.local/lib/ppm"
  ln -s "$stack" "$SOURCES/stack"

  # Only bash (the floor) and yq from wherever they are; the rest from the system dirs, which hold
  # no gh, op or fnox. A real one on PATH would be run for real.
  for t in bash yq; do ln -s "$(command -v "$t")" "$tools/$t"; done
  # ppm puts Homebrew on PATH when brew is not there (brew_env), and with it whatever is
  # installed: a brew that is found keeps the PATH as it is
  printf '#!/bin/sh\nexit 0\n' > "$tools/brew"
  chmod +x "$tools/brew"
  export PATH="$STUBS:$tools:/usr/bin:/bin:/usr/sbin:/sbin"

  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  unset SSH_CONNECTION SSH_AUTH_SOCK GH_TOKEN OP_SERVICE_ACCOUNT_TOKEN ANFS_JSON
  export ANFS_LOG=off ANFS_TABLE=tsv GIT_CONFIG_NOSYSTEM=1

  printf '# Your anfs sources\n' > "$HOME/.config/anfs/user.list"
  echo "$SOURCES/stack  stack" > "$HOME/.config/anfs/system.list"
  for t in bash zsh fish sh dash; do touch "$INSTALLED/stack/$t.yml"; done

  USER_REPO="$SOURCES/user"
  ME=(-y --name "Ada L" --email ada@example.com)
  PPMLOG="$ST/ppm.log" GHLOG="$ST/gh.log" OPLOG="$ST/op.log"
  : > "$PPMLOG"; : > "$GHLOG"; : > "$OPLOG"

  # ppm: the real one for the plumbing. install records the package and links what onboard
  # relies on; file add moves the file into the package and links it back, as the real one does.
  cat > "$HOME/.local/bin/ppm" <<SH
#!/bin/bash
if [ "\$1" = __onboard ]; then exec "$repo/packages/ppm/home/.local/bin/ppm" "\$@"; fi
echo "\$*" >> "$PPMLOG"
case "\$1 \$2" in
  "file add")
    dest="$SOURCES/\${3%%/*}/packages/\${3#*/}/home/\${4#$HOME/}"
    mkdir -p "\${dest%/*}" && mv "\$4" "\$dest" && ln -s "\$dest" "\$4" ;;
  install\ *)
    shift
    for arg in "\$@"; do
      case "\$arg" in -*) continue ;; esac
      mkdir -p "$INSTALLED/\${arg%%/*}"
      touch "$INSTALLED/\$arg.yml"
      case "\$arg" in
        user/anfs) ln -sf "$SOURCES/user/packages/anfs/home/.config/anfs/user.list" "$HOME/.config/anfs/user.list" ;;
        user/op) mkdir -p "$HOME/.config/fnox"
                 ln -sf "$SOURCES/user/packages/op/home/.config/fnox/gh.toml" "$HOME/.config/fnox/gh.toml" ;;
      esac
    done ;;
esac
SH
  chmod +x "$HOME/.local/bin/ppm"

  cat > "$STUBS/ssh-add" <<SH
#!/bin/bash
[ -s "$ST/agent-keys" ] || { echo "The agent has no identities."; exit 1; }
cat "$ST/agent-keys"
SH
  chmod +x "$STUBS/ssh-add"

  # gh: signed in; keys on the account are the lines of $ST/gh-keys; `repo create --source D
  # --push` makes a bare repo, adds it as origin and pushes
  cat > "$STUBS/gh" <<SH
#!/bin/bash
echo "\$*" >> "$GHLOG"
case "\$1 \$2" in
  "auth status") exit 0 ;;
  "auth token") echo gho_stubtoken ;;
  "api user") echo octo ;;
  "ssh-key list") cat "$ST/gh-keys" 2>/dev/null; exit 0 ;;
  "ssh-key add") printf 'host\t' >> "$ST/gh-keys"; cat >> "$ST/gh-keys" ;;
  "repo create")
    while [ \$# -gt 0 ]; do [ "\$1" = --source ] && dir="\$2"; shift; done
    git init -q --bare "$ST/remote.git"
    git -C "\$dir" remote add origin "$ST/remote.git"
    git -C "\$dir" push -q -u origin HEAD ;;
  *) exit 1 ;;
esac
SH
  chmod +x "$STUBS/gh"
}

installed() { local p; for p in "$@"; do touch "$INSTALLED/stack/$p.yml"; done; }

# op: signed in, one vault (Dev). An ssh key or the github item exists once created.
stub_op() {
  export OP_SERVICE_ACCOUNT_TOKEN=ops_stub
  pubkey vault >/dev/null
  cat > "$STUBS/op" <<SH
#!/bin/bash
echo "\$*" >> "$OPLOG"
case "\$1 \$2" in
  "vault list") echo '[{"id":"v1","name":"Dev"}]' ;;
  "item list") if [ -e "$ST/op-key" ]; then echo '[{"id":"k1"}]'; else echo '[]'; fi ;;
  "item get") [ -e "$ST/op-github" ] ;;
  "item create")
    case "\$*" in
      *"SSH Key"*) touch "$ST/op-key" ;;
      *) cat > "$ST/op-github" ;;
    esac ;;
  read\ *) [ -e "$ST/op-key" ] && cat "$ST/key-vault.pub" ;;
  *) exit 1 ;;
esac
SH
  chmod +x "$STUBS/op"
}

# A real public key, labelled <name>
pubkey() {
  ssh-keygen -q -t ed25519 -N "" -C "$1" -f "$ST/key-$1" >/dev/null
  cat "$ST/key-$1.pub"
}

onboard() { run "$ANFS" onboard "$@" </dev/null; }
col() { awk -F'\t' -v s="$1" -v c="$2" '$1 == s { print $c }' <<< "$output"; }
state() { col "$1" 3; }
order() { awk -F'\t' 'NF >= 3 && $3 ~ /^(ok|todo|optional|skip|n\/a)$/ { printf "%s ", $1 }' <<< "$output"; }

@test "not installed: the three are on offer, and bring no steps" {
  onboard --check
  [[ "$(col packages 4)" == "on offer: stack/git stack/op stack/ssh (--install)" ]]
  [ "$(order)" = "shell packages repo " ]
}

@test "the steps of all three, in the order their before and after give" {
  installed git ssh op
  stub_op
  onboard --check
  [ "$(order)" = "shell packages identity pm pm-key key access github repo publish pm-github " ]
  [ "$(col github 2)" = stack/git ]
  [ "$(col key 2)" = stack/ssh ]
  [ "$(col pm 2)" = stack/op ]
}

@test "git and ssh: identity, a key, GitHub, and a repo published to it" {
  installed git ssh
  onboard "${ME[@]}" --key local --repo new
  [ "$status" -eq 0 ]

  [ "$(git config --global user.name)" = "Ada L" ]
  [ "$(git config --global user.email)" = ada@example.com ]
  [ ! -e "$HOME/.gitconfig" ]
  # The config moved into the repo's git package and is linked back
  [ -L "$HOME/.config/git/config" ]
  [ -f "$USER_REPO/packages/git/home/.config/git/config" ]

  [ -f "$HOME/.ssh/id_ed25519.pub" ]
  grep -qF "$(awk '{print $2}' "$HOME/.ssh/id_ed25519.pub")" "$ST/gh-keys"

  grep -q "^repo create octo/anfs --private --source $USER_REPO --remote origin --push" "$GHLOG"
  [ "$(head -n 1 "$HOME/.config/anfs/user.list")" = "git@github.com:octo/anfs.git  user" ]
  [ -z "$(git -C "$USER_REPO" status --porcelain)" ]
  [ "$(git -C "$ST/remote.git" rev-list --count HEAD)" = "$(git -C "$USER_REPO" rev-list --count HEAD)" ]

  for step in identity key github repo publish; do
    [ "$(state "$step")" = ok ] || { echo "$step: $(state "$step")"; false; }
  done
}

@test "a rerun does nothing" {
  installed git ssh
  onboard "${ME[@]}" --key local --repo new
  [ "$status" -eq 0 ]
  cp "$PPMLOG" "$ST/ppm.before"
  local keys commits
  keys=$(wc -l < "$ST/gh-keys") commits=$(git -C "$USER_REPO" rev-list --count HEAD)

  onboard -y
  [ "$status" -eq 0 ]
  cmp "$PPMLOG" "$ST/ppm.before"
  [ "$(wc -l < "$ST/gh-keys")" = "$keys" ]
  [ "$(git -C "$USER_REPO" rev-list --count HEAD)" = "$commits" ]
  [ "$(grep -c '^repo create' "$GHLOG")" = 1 ]
}

@test "--repo local keeps the repo off GitHub, and a later --repo new publishes it" {
  installed git ssh
  onboard "${ME[@]}" --key local --repo local
  [ "$status" -eq 0 ]
  ! grep -q "^repo create" "$GHLOG"
  [[ "$(col publish 4)" == *"on this machine only"* ]]

  onboard -y --repo new publish
  [ "$status" -eq 0 ]
  [ "$(head -n 1 "$HOME/.config/anfs/user.list")" = "git@github.com:octo/anfs.git  user" ]
}

@test "identity alone: git is told, in ~/.config/git where a package can own it" {
  installed git
  onboard "${ME[@]}" identity
  [ "$(git config --global user.name)" = "Ada L" ]
  [ -f "$HOME/.config/git/config" ]
  [ ! -e "$USER_REPO" ]
  [ ! -s "$PPMLOG" ]
}

@test "-y cannot make up a name" {
  installed git
  onboard -y identity
  [ "$status" -eq 64 ]
  [[ "$output" == *"--name"* ]]
}

@test "a forwarded agent's key is used as it is: none is made on this host" {
  installed git ssh
  pubkey laptop > "$ST/agent-keys"
  onboard "${ME[@]}" --key agent --repo local
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.ssh/id_ed25519" ]
  grep -qF "$(awk '{print $2}' "$ST/key-laptop.pub")" "$ST/gh-keys"
  [[ "$(col key 4)" == *"(agent)" ]]
}

@test "access: agent keys are offered in an ssh session, and -y alone adds none" {
  installed ssh
  local a b
  a=$(pubkey laptop) b=$(pubkey phone)
  printf '%s\n%s\n' "$a" "$b" > "$ST/agent-keys"
  mkdir -p "$HOME/.ssh"
  echo "$a" > "$HOME/.ssh/authorized_keys"
  export SSH_CONNECTION="10.0.0.1 1 10.0.0.2 22"

  onboard --check
  [ "$(state access)" = optional ]
  [[ "$(col access 4)" == "1 agent key(s) not in authorized_keys"* ]]

  onboard -y access
  [ "$(wc -l < "$HOME/.ssh/authorized_keys" | tr -d ' ')" = 1 ]
}

@test "access: --authorize adds the named key once" {
  installed ssh
  local a b fp
  a=$(pubkey laptop) b=$(pubkey phone)
  printf '%s\n%s\n' "$a" "$b" > "$ST/agent-keys"
  export SSH_CONNECTION="10.0.0.1 1 10.0.0.2 22"
  fp=$(ssh-keygen -lf "$ST/key-phone.pub" | awk '{print $2}')

  onboard -y --authorize "$fp" access
  [ "$(cat "$HOME/.ssh/authorized_keys")" = "$b" ]
  [ "$(stat -f %Lp "$HOME/.ssh/authorized_keys" 2>/dev/null || stat -c %a "$HOME/.ssh/authorized_keys")" = 600 ]

  onboard -y --authorize all access
  [ "$(wc -l < "$HOME/.ssh/authorized_keys" | tr -d ' ')" = 2 ]
  onboard -y --authorize all access
  [ "$(wc -l < "$HOME/.ssh/authorized_keys" | tr -d ' ')" = 2 ]
  [ "$(state access)" = ok ]
}

@test "access: outside an ssh session the agent's keys are not offered" {
  installed ssh
  pubkey laptop > "$ST/agent-keys"
  onboard -y --authorize all access
  [ "$(state access)" = "n/a" ]
  [ ! -e "$HOME/.ssh/authorized_keys" ]
}

@test "1Password: the token goes into the vault, and gh is told to read it from there" {
  installed git ssh op
  stub_op
  onboard "${ME[@]}" --vault Dev --key local --repo local
  [ "$status" -eq 0 ]
  [ "$(col pm 4)" = "1Password, vault Dev" ]
  # On stdin, never as an argument
  grep -q '"value":"gho_stubtoken"' "$ST/op-github"
  ! grep -q gho_stubtoken "$OPLOG"
  grep -qF 'GH_TOKEN = { value = "op://Dev/github/token" }' "$USER_REPO/packages/op/home/.config/fnox/gh.toml"
  grep -qx "install user/op" "$PPMLOG"
  [ -z "$(git -C "$USER_REPO" status --porcelain)" ]
  [ "$(state pm-github)" = ok ]
  # The key was asked for here (--key local), so 1Password's is not offered
  [ "$(state pm-key)" = "n/a" ]
  [ ! -e "$ST/op-key" ]

  # The vault is read back from that file: a rerun needs no --vault
  onboard --check
  [ "$status" -eq 0 ]
  [ "$(col pm 4)" = "1Password, vault Dev" ]
}

@test "1Password: --key op makes the key there, and the key step uses it" {
  installed git ssh op
  stub_op
  onboard "${ME[@]}" --vault Dev --key op --repo local
  [ "$status" -eq 0 ]
  grep -q "^item create --category SSH Key .*--vault Dev --ssh-generate-key ed25519" "$OPLOG"
  [ ! -e "$HOME/.ssh/id_ed25519" ]
  [[ "$(col key 4)" == *"(1Password)" ]]
  grep -qF "$(awk '{print $2}' "$ST/key-vault.pub")" "$ST/gh-keys"
}

@test "1Password: -y does not pick a vault for you" {
  installed op
  stub_op
  onboard -y pm
  [ "$status" -eq 64 ]
  [[ "$output" == *"--vault"* ]]
}
