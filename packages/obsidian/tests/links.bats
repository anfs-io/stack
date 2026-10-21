#!/usr/bin/env bats
# Links: a vault directory symlinked into a wsm level, recorded in ovm.yml, and kept in step
# with wsm through its install and remove events.
# Run: bats packages/obsidian/tests/

load helper
setup() {
  ovm_setup
  vault notes
  mkdir -p notes/product notes/infra
  level acme
  level acme/main
  level acme/main/tech
  level acme/main/later -
  LINK="$HOME/spaces/acme/main/tech/product"
}

@test "link add records the link in ovm.yml and creates an absolute symlink in the level" {
  cd notes/product
  run ovm link add --to acme/main/tech
  [ "$status" -eq 0 ]
  [[ "$output" == *"linked ~/spaces/acme/main/tech/product -> ~/notes/product"* ]]
  [ "$(readlink "$LINK")" = "$HOME/notes/product" ]
  run yq -r '.links[0] | .source + " " + .target + " " + (.as // "none")' "$HOME/notes/ovm.yml"
  [ "$output" = "product acme/main/tech none" ]
  # ovm.yml holds no absolute path
  ! grep -q "$HOME" "$HOME/notes/ovm.yml"
}

@test "link add: DIR as an argument, --as, a source level, and the vault root itself" {
  run ovm link add notes/infra --to acme/ --as ops
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/spaces/acme/ops")" = "$HOME/notes/infra" ]
  run yq -r '.links[0] | .source + " " + .target + " " + .as' notes/ovm.yml
  [ "$output" = "infra acme ops" ]
  run ovm link add notes --to acme/main
  [ "$status" -eq 0 ]
  # The root is named after the vault
  [ "$(readlink "$HOME/spaces/acme/main/notes")" = "$HOME/notes" ]
  run yq -r '.links[1].source' notes/ovm.yml
  [ "$output" = "." ]
}

@test "link add refuses a level no source defines, a directory outside a vault, and a missing --to" {
  run ovm link add notes/product --to acme/nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"no wsm level 'acme/nope'"* ]]
  mkdir loose
  run ovm link add loose --to acme/main
  [ "$status" -eq 1 ]
  run ovm link add notes/product
  [ "$status" -eq 64 ]
  run yq -r '.links // [] | length' notes/ovm.yml
  [ "$output" = "0" ]
}

@test "link add refuses to replace what is already there, and leaves ovm.yml alone" {
  mkdir -p "$LINK"
  run ovm link add notes/product --to acme/main/tech
  [ "$status" -eq 73 ]
  [ -d "$LINK" ] && [ ! -L "$LINK" ]
  rmdir "$LINK"
  ln -s "$HOME/notes/infra" "$LINK"
  run ovm link add notes/product --to acme/main/tech
  [ "$status" -eq 73 ]
  [ "$(readlink "$LINK")" = "$HOME/notes/infra" ]
  run yq -r '.links // [] | length' notes/ovm.yml
  [ "$output" = "0" ]
}

@test "link add adopts a symlink made by hand that already leads to the directory" {
  ln -s "$HOME/notes/product" "$LINK"
  run ovm link add notes/product --to acme/main/tech
  [ "$status" -eq 0 ]
  [[ "$output" != *"linked"* ]]
  run ovm link ls notes
  [[ "$output" == "product"$'\t'"acme/main/tech"$'\t'"product"$'\t'"ok"$'\t'* ]]
}

@test "link add refuses a level inside a git repository" {
  git init -q "$HOME/spaces/acme/main/tech"
  run ovm link add notes/product --to acme/main/tech
  [ "$status" -eq 69 ]
  [[ "$output" == *"inside a git repository"* ]]
  [ ! -e "$LINK" ]
}

@test "link add to a level that is not installed is pending, and linked when wsm installs it" {
  run ovm link add notes/product --to acme/main/later
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending product -> acme/main/later"* ]]
  run ovm link ls notes
  [[ "$output" == "product"$'\t'"acme/main/later"$'\t'"product"$'\t'"pending"* ]]
  # wsm installs it, and says so
  unlevel acme/main/later
  level acme/main/later
  run ovm link apply --event install acme/main/later
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/spaces/acme/main/later/product")" = "$HOME/notes/product" ]
}

@test "adding a link again with another --as renames it" {
  ovm link add notes/product --to acme/main/tech >/dev/null
  run ovm link add notes/product --to acme/main/tech --as docs
  [ "$status" -eq 0 ]
  [ ! -e "$LINK" ]
  [ "$(readlink "$HOME/spaces/acme/main/tech/docs")" = "$HOME/notes/product" ]
  run yq -r '.links | length' notes/ovm.yml
  [ "$output" = "1" ]
}

@test "link rm removes the symlink and the entry; --to picks one of several" {
  ovm link add notes/product --to acme/main/tech >/dev/null
  ovm link add notes/product --to acme/main >/dev/null
  run ovm link rm notes/product --to acme/main </dev/null
  [ "$status" -eq 77 ]
  [ -L "$HOME/spaces/acme/main/product" ]
  run ovm link rm -y notes/product --to acme/main
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/spaces/acme/main/product" ]
  [ -L "$LINK" ]
  cd notes/product
  run ovm link rm -y
  [ "$status" -eq 0 ]
  [ ! -e "$LINK" ]
  run yq -r 'has("links")' "$HOME/notes/ovm.yml"
  [ "$output" = "false" ]
  run ovm link rm -y
  [ "$status" -eq 1 ]
}

@test "link rm leaves a path that is no longer ovm's link" {
  ovm link add notes/product --to acme/main/tech >/dev/null
  rm "$LINK"
  mkdir "$LINK"
  run ovm link rm -y notes/product
  [ "$status" -eq 0 ]
  [ -d "$LINK" ]
}

@test "link ls: every state, filtered by PATH, and across vaults from outside one" {
  ovm link add notes/product --to acme/main/tech >/dev/null
  ovm link add notes/infra --to acme/main/later >/dev/null
  ovm link add notes/infra --to acme/main >/dev/null
  rm "$HOME/spaces/acme/main/infra"
  yq -i '.links += [{"source": "gone", "target": "acme"}, {"source": "product", "target": "nope/x"}]' notes/ovm.yml
  run ovm link ls notes
  [ "${#lines[@]}" -eq 5 ]
  [[ "${lines[0]}" == "product"$'\t'"acme/main/tech"$'\t'"product"$'\t'"ok"$'\t'"~/spaces/acme/main/tech/product"$'\t'"notes" ]]
  [[ "${lines[1]}" == "infra"$'\t'"acme/main/later"$'\t'"infra"$'\t'"pending"* ]]
  [[ "${lines[2]}" == "infra"$'\t'"acme/main"$'\t'"infra"$'\t'"missing"* ]]
  [[ "${lines[3]}" == "gone"$'\t'"acme"$'\t'"gone"$'\t'"dangling"* ]]
  [[ "${lines[4]}" == "product"$'\t'"nope/x"$'\t'"product"$'\t'"unknown"* ]]
  run ovm link ls notes/infra
  [ "${#lines[@]}" -eq 2 ]
  vault other
  mkdir other/x
  ovm link add other/x --to acme >/dev/null
  run ovm link ls
  [ "${#lines[@]}" -eq 6 ]
  run ovm link ls --json
  run yq -p json -r '.[] | select(.vault == "other") | .status' <<< "$output"
  [ "$output" = "ok" ]
}

@test "link apply creates this vault's missing links and reports what it cannot" {
  ovm link add notes/product --to acme/main/tech >/dev/null
  ovm link add notes/infra --to acme/main >/dev/null
  rm "$LINK" "$HOME/spaces/acme/main/infra"
  mkdir "$HOME/spaces/acme/main/infra"
  cd notes
  run ovm link apply
  [ "$status" -eq 1 ]
  [ -L "$LINK" ]
  [[ "$output" == *"infra: ~/spaces/acme/main/infra exists and is not this link"* ]]
  rmdir "$HOME/spaces/acme/main/infra"
  run ovm link apply
  [ "$status" -eq 0 ]
  [ -L "$HOME/spaces/acme/main/infra" ]
  cd "$HOME"
  run ovm link apply
  [ "$status" -eq 1 ]
}

@test "the install event links every vault's links into the levels named, and only those" {
  vault other
  mkdir other/x
  ovm link add notes/product --to acme/main/tech >/dev/null
  ovm link add notes/infra --to acme/main >/dev/null
  ovm link add other/x --to acme/main/tech >/dev/null
  rm "$LINK" "$HOME/spaces/acme/main/infra" "$HOME/spaces/acme/main/tech/x"
  cd /
  run ovm link apply --event install acme acme/main/tech
  [ "$status" -eq 0 ]
  [ -L "$LINK" ]
  [ -L "$HOME/spaces/acme/main/tech/x" ]
  [ ! -e "$HOME/spaces/acme/main/infra" ]
}

@test "the remove event unlinks from the levels named, and a later install puts them back" {
  ovm link add notes/product --to acme/main/tech >/dev/null
  ovm link add notes/infra --to acme/main >/dev/null
  # wsm removed the level: it is no longer installed, its directory still holds ovm's link
  unlevel acme/main/tech
  level acme/main/tech -
  run ovm link apply --event remove acme/main/tech
  [ "$status" -eq 0 ]
  [ ! -e "$LINK" ]
  [ -L "$HOME/spaces/acme/main/infra" ]
  # ovm.yml did not change
  run yq -r '.links | length' notes/ovm.yml
  [ "$output" = "2" ]
  unlevel acme/main/tech
  level acme/main/tech
  ovm link apply --event install acme/main/tech
  [ -L "$LINK" ]
}

@test "the remove event leaves what replaced a link, and an event never fails its emitter" {
  ovm link add notes/product --to acme/main/tech >/dev/null
  rm "$LINK"
  echo mine > "$LINK"
  run ovm link apply --event remove acme/main/tech
  [ "$status" -eq 0 ]
  [ "$(cat "$LINK")" = mine ]
  run ovm link apply --event install acme/main/tech
  [ "$status" -eq 0 ]
  [[ "$output" == *"exists and is not this link"* ]]
  run ovm link apply --event install
  [ "$status" -eq 0 ]
}

@test "link validate: ok and pending are fine; missing, conflict, dangling, unknown and orphan are not" {
  ovm link add notes/product --to acme/main/tech >/dev/null
  ovm link add notes/infra --to acme/main/later >/dev/null
  run ovm link validate
  [ "$status" -eq 0 ]
  [ "$output" = "all links ok" ]
  rm "$LINK"
  run ovm link validate
  [ "$status" -eq 1 ]
  [[ "$output" == "product"$'\t'"acme/main/tech"$'\t'"product"$'\t'"missing"* ]]
  run ovm link validate acme/main
  [ "$status" -eq 0 ]
  # The vault directory was renamed: the link is there and leads nowhere
  ovm link apply --event install acme/main/tech
  mv notes/product notes/renamed
  run ovm link validate
  [ "$status" -eq 1 ]
  [[ "$output" == *$'\t'"dangling"$'\t'* ]]
  # The entry left ovm.yml by hand: the symlink ovm made is an orphan
  mv notes/renamed notes/product
  yq -i 'del(.links[] | select(.source == "product"))' notes/ovm.yml
  run ovm link validate --json
  [ "$status" -eq 1 ]
  run yq -p json -r '.[0] | .status + " " + .link' <<< "$output"
  [ "$output" = "orphan $LINK" ]
}

@test "without wsm, links say so with 69; the rest of ovm works" {
  rm "$BATS_TEST_TMPDIR/bin/wsm"
  PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin:$(dirname "$(command -v yq)"):$(dirname "$BASH")"
  run ovm link ls notes
  [ "$status" -eq 69 ]
  [[ "$output" == *"wsm is required"* ]]
  run ovm docs notes
  [ "$status" -eq 0 ]
}
