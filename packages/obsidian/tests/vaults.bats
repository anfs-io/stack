#!/usr/bin/env bats
# Vaults: ovm.yml as the marker, the registry that indexes them, and what happens when a vault
# moves, is renamed, or goes.
# Run: bats packages/obsidian/tests/

load helper
setup() { ovm_setup; }

@test "init writes ovm.yml with a new id and the directory's name, and registers the vault" {
  mkdir notes
  run ovm init notes
  [ "$status" -eq 0 ]
  [[ "$output" == "initialized vault notes ("*") at ~/notes" ]]
  run yq -r .id notes/ovm.yml
  [[ "$output" =~ ^[a-z2-7]{10}$ ]]
  run yq -r .name notes/ovm.yml
  [ "$output" = notes ]
  run yq -r '.profile.required | join(",")' notes/ovm.yml
  [ "$output" = "type,id" ]
  run cat "$REGISTRY"
  [[ "$output" == *$'\t'"notes"$'\t'*$'\t'"$HOME/notes" ]]
}

@test "init defaults to the current directory, and --name names the vault" {
  mkdir work && cd work
  run ovm init --name "My Vault: 2"
  [ "$status" -eq 0 ]
  run yq -r .name ovm.yml
  [ "$output" = "My Vault: 2" ]
  run ovm ls
  [[ "$output" == "My Vault: 2"$'\t'* ]]
}

@test "init again keeps the id; an ovm.yml without an id gets one and keeps the rest" {
  vault notes
  run ovm init notes
  [ "$status" -eq 0 ]
  [[ "$output" == "unchanged vault notes ($VID)"* ]]
  mkdir other
  printf '# mine\nlinks:\n  - source: a\n    target: x/y\n' > other/ovm.yml
  run ovm init other
  [ "$status" -eq 0 ]
  run yq -r .id other/ovm.yml
  [[ "$output" =~ ^[a-z2-7]{10}$ ]]
  grep -q '^# mine$' other/ovm.yml
  run yq -r '.links[0].target' other/ovm.yml
  [ "$output" = "x/y" ]
}

@test "a vault does not hold another" {
  vault notes
  mkdir -p notes/sub/deep
  run ovm init notes/sub/deep
  [ "$status" -eq 73 ]
  [[ "$output" == *"inside the vault at ~/notes"* ]]
  [ ! -e notes/sub/deep/ovm.yml ]
}

@test "new creates the directory, and refuses one that exists" {
  run ovm new fresh/vault --name fresh
  [ "$status" -eq 0 ]
  [ -f fresh/vault/ovm.yml ]
  run ovm new fresh/vault
  [ "$status" -eq 73 ]
  run ovm new
  [ "$status" -eq 64 ]
}

@test "ls lists live vaults, --stale the ones that are gone or changed id" {
  vault a
  vault b
  run ovm ls
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == "a"$'\t'*$'\t'"ok"$'\t'"~/a" ]]
  rm -rf b
  run ovm ls
  [ "${#lines[@]}" -eq 1 ]
  run ovm ls --stale
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == "b"$'\t'*$'\t'"stale"$'\t'* ]]
  # An ovm.yml that changed id is another vault: the entry is stale
  yq -i '.id = "aaaaaaaaaa"' a/ovm.yml
  run ovm ls --stale
  [ "${#lines[@]}" -eq 2 ]
}

@test "ls --json has every entry with its state" {
  vault a
  vault b
  rm -rf b
  run ovm ls --json
  [ "$status" -eq 0 ]
  run yq -p json -r '.[] | .name + "=" + .status' <<< "$output"
  [ "${lines[0]}" = "a=ok" ]
  [ "${lines[1]}" = "b=stale" ]
}

@test "a moved vault is the same vault at a new path" {
  vault a
  local id="$VID" added
  added=$(cut -f3 "$REGISTRY")
  mv a elsewhere
  run ovm scan "$HOME"
  [ "$status" -eq 0 ]
  [[ "$output" == *"moved a ($id) ~/elsewhere (was ~/a)"* ]]
  run cat "$REGISTRY"
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == "$id"$'\t'"a"$'\t'"$added"$'\t'"$HOME/elsewhere" ]]
}

@test "using a vault registers it: after a move, or one that was never registered" {
  vault a
  mv a moved
  cd moved
  run ovm path
  [ "$output" = "$HOME/moved" ]
  run ovm ls
  [[ "$output" == *"~/moved" ]]
  [ "${#lines[@]}" -eq 1 ]
  # Copied in from another machine: an ovm.yml, no registry entry
  rm "$REGISTRY"
  run ovm docs
  [ "$status" -eq 0 ]
  run ovm ls
  [[ "$output" == *"~/moved" ]]
}

@test "a rename in ovm.yml reaches the registry" {
  vault a
  yq -i '.name = "alpha"' a/ovm.yml
  cd a
  ovm path >/dev/null
  run ovm ls
  [[ "$output" == "alpha"$'\t'* ]]
}

@test "scan finds vaults, skips .git and node_modules, and warns about an ovm.yml with no id" {
  mkdir -p one two/.git/x three/node_modules/y four
  ovm init one >/dev/null
  rm "$REGISTRY"
  printf 'id: bbbbbbbbbb\n' > two/.git/x/ovm.yml
  printf 'id: cccccccccc\n' > three/node_modules/y/ovm.yml
  printf 'name: nothing\n' > four/ovm.yml
  run ovm scan
  [ "$status" -eq 0 ]
  [[ "$output" == *"added one"* ]]
  [[ "$output" == *"no id in ~/four/ovm.yml"* ]]
  [[ "$output" == *"1 vault(s) found, 1 change(s)"* ]]
  run ovm scan
  [[ "$output" == *"1 vault(s) found, 0 change(s)"* ]]
}

@test "path: the vault you are in, one by name, id or id prefix; stale exits 3" {
  vault a
  local id="$VID"
  mkdir -p a/deep/er
  cd a/deep/er
  run ovm path
  [ "$output" = "$HOME/a" ]
  cd "$HOME"
  run ovm path a
  [ "$output" = "$HOME/a" ]
  run ovm path "$id"
  [ "$output" = "$HOME/a" ]
  run ovm path "${id:0:4}"
  [ "$output" = "$HOME/a" ]
  run ovm path "${id:0:3}"
  [ "$status" -eq 1 ]
  run ovm path
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a vault"* ]]
  rm -rf a
  run ovm path a
  [ "$status" -eq 3 ]
  [[ "$output" == *"$HOME/a"* ]]
}

@test "an ambiguous name exits 2 and lists the candidates" {
  mkdir -p x/notes y/notes
  ovm init x/notes >/dev/null
  ovm init y/notes >/dev/null
  run ovm path notes
  [ "$status" -eq 2 ]
  [[ "$output" == *"~/x/notes"* && "$output" == *"~/y/notes"* ]]
}

@test "remove drops one entry and leaves the files; prune drops the stale ones" {
  vault a
  vault b
  vault c
  # it asks: no terminal and no -y is 77, and the entry stays
  run ovm remove a </dev/null
  [ "$status" -eq 77 ]
  run ovm ls
  [ "${#lines[@]}" -eq 3 ]
  run ovm remove -y a
  [ "$status" -eq 0 ]
  [ -f a/ovm.yml ]
  run ovm ls
  [ "${#lines[@]}" -eq 2 ]
  run ovm remove -y a
  [ "$status" -eq 1 ]
  rm -rf b
  run ovm prune -n
  [[ "$output" == "would drop b"* ]]
  run ovm prune --dry-run
  [[ "$output" == "would drop b"* ]]
  run ovm ls --stale
  [ "${#lines[@]}" -eq 1 ]
  run ovm prune </dev/null
  [ "$status" -eq 77 ]
  run ovm ls --stale
  [ "${#lines[@]}" -eq 1 ]
  run ovm prune -y
  [[ "$output" == "dropped b"* ]]
  run cat "$REGISTRY"
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == *$'\t'"c"$'\t'* ]]
}

@test "concurrent inits all land in the registry" {
  local i
  for i in 1 2 3 4 5 6; do mkdir "v$i"; done
  for i in 1 2 3 4 5 6; do ovm init "v$i" >/dev/null & done
  wait
  run cat "$REGISTRY"
  [ "${#lines[@]}" -eq 6 ]
  [ ! -e "$XDG_STATE_HOME/ovm/vaults.lock" ]
}

@test "a stale lock is cleared; a held one fails with 75" {
  mkdir -p "$XDG_STATE_HOME/ovm/vaults.lock" a
  echo 1 > "$XDG_STATE_HOME/ovm/vaults.lock/created"
  run ovm init a
  [ "$status" -eq 0 ]
  [[ "$output" == *"clearing a stale lock"* ]]
  mkdir b "$XDG_STATE_HOME/ovm/vaults.lock"
  date +%s > "$XDG_STATE_HOME/ovm/vaults.lock/created"
  run ovm init b
  [ "$status" -eq 75 ]
}

@test "the options every tool takes, --version, and an unknown command" {
  run ovm --version
  [[ "$output" == ovm\ * ]]
  run ovm help
  [[ "$output" == *"link <add|remove|list|apply|validate>"* ]]
  [[ "$output" == *"list, ls [--stale]"* ]]
  [[ "$output" == *"remove, rm [-y] <vault>"* ]]
  [[ "$output" == *"-d, --debug"* ]]
  run ovm nope
  [ "$status" -eq 64 ]
  vault a
  mv a b
  cd b
  run ovm -d path
  [[ "$output" == *"ovm: debug: registry: moved a"* ]]
}

@test "a tab press: commands once with their aliases, a vault by name, options after a -" {
  vault a
  run ovm __complete ""
  [[ "$output" == *"list"$'\t'"The vaults this machine knows (alias: ls)"* ]]
  ! grep -qE '^(ls|rm)	' <<< "$output"
  run ovm __complete path ""
  [ "$output" = "a"$'\t'"~/a" ]
  run ovm __complete link ""
  [[ "$output" == *"remove"$'\t'*"(alias: rm)"* ]]
  run ovm __complete link add ""
  [ "$output" = ":dirs" ]
  run ovm __complete link add "-"
  [[ "$output" == *"--to"$'\t'* && "$output" == *"--as"$'\t'* ]]
  # A tab press does not register the vault you are in, or write anything
  rm "$REGISTRY"
  (cd a && ovm __complete "" >/dev/null)
  [ ! -e "$REGISTRY" ]
}
