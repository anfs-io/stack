#!/usr/bin/env bats
# Vault spaces: the folders under a vault's spaces_path, linked into wsm spaces as
# ~/.config/ovm/links.yml declares (links.local.yml beside it for one machine), and kept in step
# with wsm through its install and remove events.
# Run: bats packages/obsidian/tests/

load helper
setup() {
  ovm_setup
  vault notes
  mkdir -p vaults/notes/spaces/product vaults/notes/spaces/infra
  level acme
  level acme/main
  level acme/main/tech
  level acme/main/later -
  LINKS="$XDG_CONFIG_HOME/ovm/links.yml"
  LINK="$HOME/spaces/acme/main/tech/product"
  PRODUCT="$HOME/vaults/notes/spaces/product"
}

# <link> is relative (lib/anfs/link.sh's anfs_link_one) and resolves to <dir>
points() { [[ "$(readlink "$1")" != /* ]] && [ "$(cd -P "$1" && pwd -P)" = "$(cd -P "$2" && pwd -P)" ]; }

# The pairs links.yml declares: vault/space>to[@as], one per line
declared() { yq -r '.[] | .vault + "/" + .space + ">" + ([.to] | flatten | join(",")) + (select(has("as")) | "@" + .as // "")' "${1:-$LINKS}"; }

@test "space list in a vault: the folders under spaces/, hidden ones and files left out; unlinked" {
  mkdir -p vaults/notes/spaces/.hidden vaults/notes/spaces/journal vaults/notes/other
  touch vaults/notes/spaces/afile
  cd vaults/notes
  run ovm space list
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "infra"$'\t'"-"$'\t'"-"$'\t'"unlinked"$'\t'"-"$'\t'"notes" ]
  [ "${lines[1]}" = "journal"$'\t'"-"$'\t'"-"$'\t'"unlinked"$'\t'"-"$'\t'"notes" ]
  [ "${lines[2]}" = "product"$'\t'"-"$'\t'"-"$'\t'"unlinked"$'\t'"-"$'\t'"notes" ]
  run ovm space ls --json
  run yq -p json -r '.[2] | [.space, .status, .vault, .path] | join(" ")' <<< "$output"
  [ "$output" = "product unlinked notes $PRODUCT" ]
  # A custom spaces_path
  yq -i '.spaces_path = "areas/"' vault.yml
  mkdir -p areas/home
  run ovm space list
  [ "$output" = "home"$'\t'"-"$'\t'"-"$'\t'"unlinked"$'\t'"-"$'\t'"notes" ]
  # Outside a vault: every vault, or the one named
  cd "$HOME"
  vault other
  mkdir -p vaults/other/spaces/x
  run ovm space list
  [ "${#lines[@]}" -eq 2 ]
  run ovm space list other
  [ "$output" = "x"$'\t'"-"$'\t'"-"$'\t'"unlinked"$'\t'"-"$'\t'"other" ]
  run ovm space list nope
  [ "$status" -eq 1 ]
}

@test "space add makes the folder, is fine with one that is there, and never writes vault.yml" {
  cp vaults/notes/vault.yml "$BATS_TEST_TMPDIR/before"
  cd vaults/notes
  run ovm space add journal
  [ "$status" -eq 0 ]
  [ -d spaces/journal ]
  run ovm space add notes/journal
  [ "$status" -eq 0 ]
  [[ "$output" == *"already a space"* ]]
  cmp vault.yml "$BATS_TEST_TMPDIR/before"
  # A path: the folders above it made too; the first part is always the vault
  run ovm space add notes/area/deep/er
  [ "$status" -eq 0 ]
  [ -d spaces/area/deep/er ]
  run ovm space add a/b/c
  [ "$status" -eq 1 ]
  [[ "$output" == *"no vault 'a'"* ]]
  run ovm space add .hidden
  [ "$status" -eq 64 ]
  for bad in notes/../x notes/a/.b notes/a//b; do
    run ovm space add "$bad"
    [ "$status" -eq 64 ]
  done
  [ ! -e ../x ]
  cd "$HOME"
  run ovm space add journal
  [ "$status" -eq 64 ]
  [[ "$output" == *"name the vault: <vault>/journal"* ]]
  run ovm space add nope/journal
  [ "$status" -eq 1 ]
  [ ! -e "$LINKS" ]
}

@test "space link declares the pair in links.yml and makes a relative link in the wsm space" {
  run ovm space link notes/product acme/main/tech
  [ "$status" -eq 0 ]
  [[ "$output" == *"linked ~/spaces/acme/main/tech/product -> ~/vaults/notes/spaces/product"* ]]
  points "$LINK" "$PRODUCT"
  [ "$(declared)" = "notes/product>acme/main/tech" ]
  # links.yml holds no path
  ! grep -q "$HOME" "$LINKS"
  # A second wsm space goes in the same entry's to:
  run ovm space link notes/product acme/main/
  [ "$status" -eq 0 ]
  [ "$(declared)" = "notes/product>acme/main/tech,acme/main" ]
  points "$HOME/spaces/acme/main/product" "$PRODUCT"
  run ovm space list
  [ "${#lines[@]}" -eq 3 ]
  [[ "$output" == *"product"$'\t'"acme/main/tech"$'\t'"product"$'\t'"ok"$'\t'"~/spaces/acme/main/tech/product"$'\t'"notes"* ]]
  # The comments of links.yml are kept
  grep -q '^# Which vault spaces' "$LINKS"
}

@test "space link --as names the link; again with another --as renames it" {
  run ovm space link notes/product acme/main/tech --as docs
  [ "$status" -eq 0 ]
  points "$HOME/spaces/acme/main/tech/docs" "$PRODUCT"
  [ "$(declared)" = "notes/product>acme/main/tech@docs" ]
  run ovm space link notes/product acme/main/tech --as manual
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/spaces/acme/main/tech/docs" ]
  points "$HOME/spaces/acme/main/tech/manual" "$PRODUCT"
  [ "$(declared)" = "notes/product>acme/main/tech@manual" ]
  # Back to the default name
  run ovm space link notes/product acme/main/tech
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/spaces/acme/main/tech/manual" ]
  points "$LINK" "$PRODUCT"
  [ "$(declared)" = "notes/product>acme/main/tech" ]
}

@test "many to many: two vaults' product in one wsm space need --as; one space in two wsm spaces" {
  vault other
  mkdir -p vaults/other/spaces/product
  ovm space link notes/product acme/main/tech >/dev/null
  run ovm space link other/product acme/main/tech
  [ "$status" -eq 73 ]
  [[ "$output" == *"exists and is not this link"*"--as"* ]]
  [ "$(declared)" = "notes/product>acme/main/tech" ]
  run ovm space link other/product acme/main/tech --as other
  [ "$status" -eq 0 ]
  points "$HOME/spaces/acme/main/tech/other" "$HOME/vaults/other/spaces/product"
  points "$LINK" "$PRODUCT"
  run ovm space link notes/product acme
  [ "$status" -eq 0 ]
  points "$HOME/spaces/acme/product" "$PRODUCT"
  run ovm space list notes
  [ "${#lines[@]}" -eq 3 ]
}

@test "space link refuses an unknown wsm space, a missing folder, a conflict, a git repository; links.yml unchanged" {
  links "# mine\n"
  cp "$LINKS" "$BATS_TEST_TMPDIR/before"
  run ovm space link notes/product acme/nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"no wsm space 'acme/nope'"* ]]
  run ovm space link notes/nope acme/main/tech
  [ "$status" -eq 1 ]
  [[ "$output" == *"no folder ~/vaults/notes/spaces/nope: ovm space add notes/nope"* ]]
  mkdir -p "$LINK"
  run ovm space link notes/product acme/main/tech
  [ "$status" -eq 73 ]
  [ -d "$LINK" ] && [ ! -L "$LINK" ]
  rmdir "$LINK"
  git init -q "$HOME/spaces/acme/main/tech"
  run ovm space link notes/product acme/main/tech
  [ "$status" -eq 69 ]
  [[ "$output" == *"inside a git repository"* ]]
  [ ! -e "$LINK" ]
  run ovm space link notes/product
  [ "$status" -eq 64 ]
  run ovm space link notes/product acme/main --as a/b
  [ "$status" -eq 64 ]
  cmp "$LINKS" "$BATS_TEST_TMPDIR/before"
}

@test "a bare space names one in the vault you are in; outside one it is 64; vault/space works anywhere" {
  cd vaults/notes/spaces
  run ovm space link product acme/main/tech
  [ "$status" -eq 0 ]
  cd /
  run ovm space unlink product
  [ "$status" -eq 64 ]
  [[ "$output" == *"name the vault"* ]]
  run ovm space unlink notes/product
  [ "$status" -eq 0 ]
}

@test "a link made by hand that already leads to the folder is adopted; one to a pending wsm space links on install" {
  ln -s "$PRODUCT" "$LINK"
  run ovm space link notes/product acme/main/tech
  [ "$status" -eq 0 ]
  [[ "$output" != *"linked"* ]]
  [ "$(readlink "$LINK")" = "$PRODUCT" ]
  run ovm space list notes
  [[ "$output" == "infra"*$'\n'"product"$'\t'"acme/main/tech"$'\t'"product"$'\t'"ok"* ]]
  run ovm space link notes/product acme/main/later
  [ "$status" -eq 0 ]
  [[ "$output" == *"pending notes/product -> acme/main/later"* ]]
  unlevel acme/main/later
  level acme/main/later
  run ovm space apply --event install acme/main/later
  [ "$status" -eq 0 ]
  points "$HOME/spaces/acme/main/later/product" "$PRODUCT"
}

@test "space unlink: one wsm space or all, only what ovm made; an entry left with no to goes" {
  ovm space link notes/product acme/main/tech >/dev/null
  ovm space link notes/product acme/main >/dev/null
  ovm space link notes/infra acme/main >/dev/null
  run ovm space unlink notes/product acme/main
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/spaces/acme/main/product" ]
  [ -L "$LINK" ]
  [ "$(declared)" = "notes/product>acme/main/tech"$'\n'"notes/infra>acme/main" ]
  # What replaced ovm's link stays
  rm "$LINK" && mkdir "$LINK"
  run ovm space unlink notes/product
  [ "$status" -eq 0 ]
  [ -d "$LINK" ]
  [ "$(declared)" = "notes/infra>acme/main" ]
  run ovm space unlink notes/product
  [ "$status" -eq 1 ]
  run ovm space unlink notes/infra acme/main/tech
  [ "$status" -eq 1 ]
  [ -L "$HOME/spaces/acme/main/infra" ]
}

@test "links.yml shipped (a link): space link writes links.local.yml; unlink leaves the shipped entry" {
  mkdir -p "$BATS_TEST_TMPDIR/repo" "$XDG_CONFIG_HOME/ovm"
  printf -- '- vault: notes\n  space: product\n  to: [acme/main/tech]\n' > "$BATS_TEST_TMPDIR/repo/links.yml"
  ln -s "$BATS_TEST_TMPDIR/repo/links.yml" "$LINKS"
  cp "$BATS_TEST_TMPDIR/repo/links.yml" "$BATS_TEST_TMPDIR/before"
  run ovm space link notes/infra acme/main
  [ "$status" -eq 0 ]
  [[ "$output" == *"~/.config/ovm/links.yml is shipped (a link): writing ~/.config/ovm/links.local.yml"* ]]
  [ "$(declared "$XDG_CONFIG_HOME/ovm/links.local.yml")" = "notes/infra>acme/main" ]
  cmp "$BATS_TEST_TMPDIR/repo/links.yml" "$BATS_TEST_TMPDIR/before"
  # Both files' links are made and listed; a pair in both is one
  printf -- '- vault: notes\n  space: product\n  to: acme/main/tech\n' >> "$XDG_CONFIG_HOME/ovm/links.local.yml"
  run ovm space apply
  [ "$status" -eq 0 ]
  points "$LINK" "$PRODUCT"
  run ovm space list notes
  [ "${#lines[@]}" -eq 2 ]
  [[ "$output" == *"product"$'\t'"acme/main/tech"$'\t'"product"$'\t'"ok"* ]]
  # The shipped pair is the repository's to remove
  run ovm space unlink notes/product acme/main/tech
  [ "$status" -eq 1 ]
  [[ "$output" == *"declared in ~/.config/ovm/links.yml, which is shipped (a link): edit it there"* ]]
  [ -L "$LINK" ]
  cmp "$BATS_TEST_TMPDIR/repo/links.yml" "$BATS_TEST_TMPDIR/before"
  # A local one goes
  run ovm space unlink notes/infra
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/spaces/acme/main/infra" ]
}

@test "an invalid links.yml: every space command is 64, docs --to too, and nothing is linked" {
  local bad
  for bad in "- vault: notes\n  space: product\n" "- vault: notes\n  space: product\n  to: [acme]\n  source: x\n" \
             "vault: notes\n" "- just a string\n" "- vault: notes\n  space: a/../b\n  to: acme\n" "- vault: notes\n  space: /abs\n  to: acme\n" "- vault: notes\n  space: product\n  to: []\n"; do
    links "$bad"
    run ovm space link notes/infra acme/main
    [ "$status" -eq 64 ]
    [[ "$output" == *"~/.config/ovm/links.yml"* ]]
    run ovm space apply
    [ "$status" -eq 64 ]
    run ovm space list
    [ "$status" -eq 64 ]
    run ovm space add notes/x
    [ "$status" -eq 64 ]
    run ovm docs --to acme
    [ "$status" -eq 64 ]
    # Elsewhere a document's space is only the first folder: said, not refused
    run ovm docs notes
    [ "$status" -eq 0 ]
  done
  links "- vault: notes\n  space: product\n  to: [acme]\n  source: x\n"
  run ovm space list
  [[ "$output" == *"links.yml: entry 1: unknown key 'source'"* ]]
  [ ! -e "$HOME/spaces/acme/main/infra" ]
  # wsm's event never fails: it says why and does nothing
  run ovm space apply --event install acme
  [ "$status" -eq 0 ]
  [[ "$output" == *"no links read"* ]]
  [ ! -e "$HOME/spaces/acme/product" ]
}

@test "space remove unlinks from every wsm space and leaves the folder; asks without -y" {
  ovm space link notes/product acme/main/tech >/dev/null
  ovm space link notes/product acme/main >/dev/null
  file vaults/notes/spaces/product/note.md "mine\n"
  run ovm space rm notes/product </dev/null
  [ "$status" -eq 77 ]
  [ -L "$LINK" ]
  run ovm space remove -y notes/product
  [ "$status" -eq 0 ]
  [ ! -e "$LINK" ] && [ ! -e "$HOME/spaces/acme/main/product" ]
  [ -f vaults/notes/spaces/product/note.md ]
  [ -z "$(declared)" ]
  run ovm space remove -y notes/product
  [ "$status" -eq 1 ]
}

@test "nested vault spaces: a deeper folder links by its path; nested links into one wsm space need different names" {
  mkdir -p vaults/notes/spaces/anfs/product vaults/notes/spaces/anfs/inbox
  run ovm space link notes/anfs/product acme/main/tech --as apex
  [ "$status" -eq 0 ]
  points "$HOME/spaces/acme/main/tech/apex" "$HOME/vaults/notes/spaces/anfs/product"
  [ "$(declared)" = "notes/anfs/product>acme/main/tech@apex" ]
  # The space holding it, into the same wsm space: the same name is a conflict, another is fine
  run ovm space link notes/anfs acme/main/tech --as apex
  [ "$status" -eq 73 ]
  run ovm space link notes/anfs acme/main/tech
  [ "$status" -eq 0 ]
  points "$HOME/spaces/acme/main/tech/anfs" "$HOME/vaults/notes/spaces/anfs"
  # A deeper space's default name is its folder's
  run ovm space link notes/anfs/product acme/main
  [ "$status" -eq 0 ]
  points "$HOME/spaces/acme/main/product" "$HOME/vaults/notes/spaces/anfs/product"
  # --as equal to the folder's name is no as
  [[ "$(declared)" == *"notes/anfs/product>acme/main"$'\n'* || "$(declared)" == *"notes/anfs/product>acme/main" ]]
  # list: the top-level folders and the linked deeper one, by path; an unlinked deeper one is not
  run ovm space list notes
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
  [ "${lines[0]}" = "anfs"$'\t'"acme/main/tech"$'\t'"anfs"$'\t'"ok"$'\t'"~/spaces/acme/main/tech/anfs"$'\t'"notes" ]
  [[ "$output" == *"anfs/product"$'\t'"acme/main/tech"$'\t'"apex"$'\t'"ok"* ]]
  [[ "$output" == *"anfs/product"$'\t'"acme/main"$'\t'"product"$'\t'"ok"* ]]
  [[ "$output" != *"anfs/inbox"* ]]
  # Unlinking the outer one leaves the inner one's links
  run ovm space unlink notes/anfs
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/spaces/acme/main/tech/anfs" ]
  points "$HOME/spaces/acme/main/tech/apex" "$HOME/vaults/notes/spaces/anfs/product"
  run ovm space remove notes/anfs/product -y
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/spaces/acme/main/tech/apex" ] && [ ! -e "$HOME/spaces/acme/main/product" ]
  [ -d vaults/notes/spaces/anfs/product ]
  # apply makes a declared deeper one
  links "- vault: notes\n  space: anfs/product/\n  to: acme\n"
  run ovm space apply
  [ "$status" -eq 0 ]
  points "$HOME/spaces/acme/product" "$HOME/vaults/notes/spaces/anfs/product"
}

@test "spaces_path: . makes the folders at the vault's root its spaces" {
  yq -i '.spaces_path = "."' vaults/notes/vault.yml
  mkdir -p vaults/notes/journal vaults/notes/_templates vaults/notes/.obsidian
  cd vaults/notes
  run ovm space list
  [ "$status" -eq 0 ]
  [ "$output" = "journal"$'\t'"-"$'\t'"-"$'\t'"unlinked"$'\t'"-"$'\t'"notes"$'\n'"spaces"$'\t'"-"$'\t'"-"$'\t'"unlinked"$'\t'"-"$'\t'"notes" ]
  run ovm space add work
  [ "$status" -eq 0 ]
  [ -d work ]
  run ovm space link notes/spaces/product acme/main/tech
  [ "$status" -eq 0 ]
  points "$LINK" "$PRODUCT"
  run ovm space list --json
  run yq -p json -r '.[] | select(.space == "spaces/product") | .status + " " + .path' <<< "$output"
  [ "$output" = "ok $PRODUCT" ]
  run ovm validate
  [[ "$output" != *"spaces_path"* ]]
}

@test "space list: no vault, no folder, orphan, pending, conflict, dangling, missing; --problems" {
  ovm space link notes/product acme/main/tech >/dev/null
  ovm space link notes/infra acme/main/later >/dev/null
  run ovm space list --problems
  [ "$status" -eq 0 ]
  [ "$output" = "no problems" ]
  # The vault, the folder, the wsm space: each can be gone
  printf -- '- vault: gone\n  space: x\n  to: acme\n- vault: notes\n  space: nofolder\n  to: acme\n- vault: notes\n  space: infra\n  to: nope/x\n' >> "$LINKS"
  ovm space link notes/infra acme/main >/dev/null
  rm "$HOME/spaces/acme/main/infra"
  run ovm space list
  [ "$status" -eq 0 ]
  [[ "$output" == *"infra"$'\t'"acme/main/later"$'\t'"infra"$'\t'"pending"* ]]
  [[ "$output" == *"infra"$'\t'"acme/main"$'\t'"infra"$'\t'"missing"* ]]
  [[ "$output" == *"infra"$'\t'"nope/x"$'\t'"infra"$'\t'"unknown"* ]]
  [[ "$output" == *"nofolder"$'\t'"acme"$'\t'"nofolder"$'\t'"no folder"* ]]
  [[ "$output" == *"x"$'\t'"acme"$'\t'"x"$'\t'"no vault"$'\t'"-"$'\t'"gone"* ]]
  # In a vault, only its own
  cd vaults/notes
  run ovm space list
  [[ "$output" != *"no vault"* ]]
  cd "$HOME"
  run ovm space list --problems
  [ "$status" -eq 1 ]
  [[ "$output" != *ok* && "$output" != *pending* ]]
  # Something else where the link should be
  rm "$LINK"; mkdir "$LINK"
  run ovm space list --problems --json
  [ "$status" -eq 1 ]
  run yq -p json -r '.[] | select(.space == "product") | .status' <<< "$output"
  [ "$output" = conflict ]
  rmdir "$LINK"
  ovm space apply --event install acme/main/tech >/dev/null
  # The folder was renamed: ovm's link leads nowhere
  mv vaults/notes/spaces/product vaults/notes/spaces/renamed
  run ovm space list notes
  [[ "$output" == *"product"$'\t'"acme/main/tech"$'\t'"product"$'\t'"dangling"* ]]
  [[ "$output" == *"renamed"$'\t'"-"$'\t'"-"$'\t'"unlinked"* ]]
  mv vaults/notes/spaces/renamed vaults/notes/spaces/product
  # The entry left links.yml by hand: the symlink ovm made is an orphan
  yq -i 'del(.[] | select(.space == "product"))' "$LINKS"
  run ovm space list --problems --json
  [ "$status" -eq 1 ]
  run yq -p json -r '.[] | select(.status == "orphan") | .space + " " + .vault + " " + .link' <<< "$output"
  [ "$output" = "product notes $LINK" ]
}

@test "space apply makes every missing link links.yml declares, machine-wide, and says what it cannot" {
  vault other
  mkdir -p vaults/other/spaces/x
  links "- vault: notes\n  space: product\n  to: [acme/main/tech, acme/main/later]\n- vault: notes\n  space: infra\n  to: acme/main\n- vault: other\n  space: x\n  to: acme\n- vault: gone\n  space: y\n  to: acme\n"
  mkdir "$HOME/spaces/acme/main/infra"
  cd /
  run ovm space apply
  [ "$status" -eq 1 ]
  points "$LINK" "$PRODUCT"
  points "$HOME/spaces/acme/x" "$HOME/vaults/other/spaces/x"
  [[ "$output" == *"notes/infra: ~/spaces/acme/main/infra exists and is not this link"* ]]
  [[ "$output" == *"pending notes/product -> acme/main/later"* ]]
  rmdir "$HOME/spaces/acme/main/infra"
  run ovm space apply acme/main
  [ "$status" -eq 0 ]
  [ -L "$HOME/spaces/acme/main/infra" ]
}

@test "the install event links every vault's spaces declared into the wsm spaces named, and only those" {
  vault other
  mkdir -p vaults/other/spaces/x
  links "- vault: notes\n  space: product\n  to: [acme/main/tech]\n- vault: notes\n  space: infra\n  to: acme/main\n- vault: other\n  space: x\n  to: acme/main/tech\n"
  cd /
  run ovm space apply --event install acme acme/main/tech
  [ "$status" -eq 0 ]
  [ -L "$LINK" ]
  [ -L "$HOME/spaces/acme/main/tech/x" ]
  [ ! -e "$HOME/spaces/acme/main/infra" ]
}

@test "the remove event unlinks from the wsm spaces named, and a later install puts them back" {
  ovm space link notes/product acme/main/tech >/dev/null
  ovm space link notes/infra acme/main >/dev/null
  # wsm removed the space: it is no longer installed, its directory still holds ovm's link
  unlevel acme/main/tech
  level acme/main/tech -
  run ovm space apply --event remove acme/main/tech
  [ "$status" -eq 0 ]
  [ ! -e "$LINK" ]
  [ -L "$HOME/spaces/acme/main/infra" ]
  # links.yml did not change
  [ "$(declared)" = "notes/product>acme/main/tech"$'\n'"notes/infra>acme/main" ]
  unlevel acme/main/tech
  level acme/main/tech
  ovm space apply --event install acme/main/tech
  [ -L "$LINK" ]
}

@test "the remove event leaves what replaced a link, and an event never fails its emitter" {
  ovm space link notes/product acme/main/tech >/dev/null
  rm "$LINK"
  echo mine > "$LINK"
  run ovm space apply --event remove acme/main/tech
  [ "$status" -eq 0 ]
  [ "$(cat "$LINK")" = mine ]
  run ovm space apply --event install acme/main/tech
  [ "$status" -eq 0 ]
  [[ "$output" == *"exists and is not this link"* ]]
  run ovm space apply --event install
  [ "$status" -eq 0 ]
  run ovm space apply --event nope acme
  [ "$status" -eq 64 ]
}

@test "without wsm, space link and apply say so with 69; space list still lists the folders" {
  rm "$BATS_TEST_TMPDIR/bin/wsm"
  PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin:$(dirname "$(command -v yq)"):$(dirname "$BASH")"
  run ovm space link notes/product acme/main
  [ "$status" -eq 69 ]
  [[ "$output" == *"wsm is required"* ]]
  run ovm space apply
  [ "$status" -eq 69 ]
  run ovm space list notes
  [ "$status" -eq 0 ]
  [[ "$output" == *"product"$'\t'"-"$'\t'"-"$'\t'"unlinked"* ]]
  run ovm docs notes
  [ "$status" -eq 0 ]
}

@test "the link group is gone" {
  run ovm link list
  [ "$status" -eq 64 ]
  run ovm link add --to acme
  [ "$status" -eq 64 ]
}

@test "the record of links is locked: a stale lock is cleared, a held one fails with 75" {
  mkdir -p "$XDG_STATE_HOME/ovm/links.lock"
  echo 1 > "$XDG_STATE_HOME/ovm/links.lock/created"
  run ovm space link notes/product acme/main/tech
  [ "$status" -eq 0 ]
  [[ "$output" == *"clearing a stale lock"* ]]
  [ ! -e "$XDG_STATE_HOME/ovm/links.lock" ]
  mkdir "$XDG_STATE_HOME/ovm/links.lock"
  date +%s > "$XDG_STATE_HOME/ovm/links.lock/created"
  run ovm space link notes/infra acme/main
  [ "$status" -eq 75 ]
}
