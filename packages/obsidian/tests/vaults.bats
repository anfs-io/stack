#!/usr/bin/env bats
# Vaults: the entries of ~/vaults (OVM_VAULTS_HOME), each a directory or a link to one with an
# ovm.yml, named by the entry. No registry, no scan.
# Run: bats packages/obsidian/tests/

load helper
setup() { ovm_setup; }

@test "init writes ovm.yml with a new id in an entry of ~/vaults, and list shows it" {
  mkdir -p vaults/notes
  run ovm init vaults/notes
  [ "$status" -eq 0 ]
  [[ "$output" == "initialized vault notes ("*") at ~/vaults/notes" ]]
  run yq -r .id vaults/notes/ovm.yml
  [[ "$output" =~ ^[a-z2-7]{10}$ ]]
  local id="$output"
  run yq -r '.profile.required | join(",")' vaults/notes/ovm.yml
  [ "$output" = "type,id" ]
  # The name is the entry's: ovm.yml carries none
  run yq -r 'has("name")' vaults/notes/ovm.yml
  [ "$output" = false ]
  run ovm ls
  [ "$output" = "notes"$'\t'"$id"$'\t'"ok"$'\t'"~/vaults/notes" ]
}

@test "init defaults to the current directory; again it keeps the id; an ovm.yml without an id gets one" {
  mkdir -p vaults/work && cd vaults/work
  run ovm init
  [ "$status" -eq 0 ]
  local id
  id=$(yq -r .id ovm.yml)
  run ovm init
  [ "$status" -eq 0 ]
  [ "$output" = "vault work ($id) at ~/vaults/work is initialized already" ]
  [ "$(yq -r .id ovm.yml)" = "$id" ]
  mkdir ../other
  printf '# mine\nlinks:\n  - source: a\n    target: x/y\n' > ../other/ovm.yml
  run ovm init ../other
  [ "$status" -eq 0 ]
  run yq -r .id ../other/ovm.yml
  [[ "$output" =~ ^[a-z2-7]{10}$ ]]
  grep -q '^# mine$' ../other/ovm.yml
  run yq -r '.links[0].target' ../other/ovm.yml
  [ "$output" = "x/y" ]
}

@test "init outside ~/vaults is refused with the hint to link it there; a linked one is named by its entry" {
  mkdir -p elsewhere/apex vaults/notes/sub
  run ovm init elsewhere/apex
  [ "$status" -eq 1 ]
  [[ "$output" == *"~/elsewhere/apex is not in ~/vaults"*"ln -s '$HOME/elsewhere/apex' ~/vaults/<name>"* ]]
  [ ! -e elsewhere/apex/ovm.yml ]
  # Below an entry is not an entry either
  run ovm init vaults/notes/sub
  [ "$status" -eq 1 ]
  [ ! -e vaults/notes/sub/ovm.yml ]
  # Linked into ~/vaults under another name: init by the link or by the real path
  ln -s ../elsewhere/apex vaults/main
  run ovm init elsewhere/apex
  [ "$status" -eq 0 ]
  [[ "$output" == "initialized vault main ("*") at ~/elsewhere/apex" ]]
  [ -f elsewhere/apex/ovm.yml ]
  run ovm init vaults/main
  [[ "$output" == "vault main ("*") at ~/elsewhere/apex is initialized already" ]]
}

@test "a vault does not hold another" {
  mkdir -p big/vaults/inner
  printf 'id: aaaaaaaaaa\n' > big/ovm.yml
  OVM_VAULTS_HOME="$HOME/big/vaults" run ovm init big/vaults/inner
  [ "$status" -eq 73 ]
  [[ "$output" == *"inside the vault at ~/big"* ]]
  [ ! -e big/vaults/inner/ovm.yml ]
}

@test "new creates ~/vaults/NAME and inits it; an existing entry, a path or no name is refused" {
  run ovm new fresh
  [ "$status" -eq 0 ]
  [[ "$output" == "initialized vault fresh ("*") at ~/vaults/fresh" ]]
  [ -f vaults/fresh/ovm.yml ]
  run ovm new fresh
  [ "$status" -eq 73 ]
  ln -s nowhere vaults/dangling
  run ovm new dangling
  [ "$status" -eq 73 ]
  run ovm new some/path
  [ "$status" -eq 64 ]
  [ ! -e vaults/some ]
  run ovm new .hidden
  [ "$status" -eq 64 ]
  run ovm new
  [ "$status" -eq 64 ]
}

@test "list reads only ~/vaults: a directory, a link to one, a dangling link, an entry that is not a vault" {
  vault a
  local a="$VID"
  mkdir -p icloud/apex vaults/plain elsewhere/loose
  printf 'id: bbbbbbbbbb\n' > icloud/apex/ovm.yml
  ln -s ../icloud/apex vaults/apex
  ln -s ../icloud/gone vaults/gone
  touch vaults/afile vaults/.DS_Store
  # An ovm.yml outside ~/vaults is not a vault ovm knows
  printf 'id: cccccccccc\n' > elsewhere/loose/ovm.yml
  run ovm ls
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
  [ "${lines[0]}" = "a"$'\t'"$a"$'\t'"ok"$'\t'"~/vaults/a" ]
  [ "${lines[1]}" = "afile"$'\t'"-"$'\t'"not a vault"$'\t'"~/vaults/afile" ]
  [ "${lines[2]}" = "apex"$'\t'"bbbbbbbbbb"$'\t'"ok"$'\t'"~/icloud/apex" ]
  [ "${lines[3]}" = "gone"$'\t'"-"$'\t'"unreachable"$'\t'"../icloud/gone" ]
  [ "${lines[4]}" = "plain"$'\t'"-"$'\t'"not a vault"$'\t'"~/vaults/plain" ]
  [[ "$output" != *loose* && "$output" != *cccccccccc* ]]
  run ovm ls --json
  run yq -p json -r '.[] | .name + "=" + .status' <<< "$output"
  [ "$output" = "a=ok"$'\n'"afile=not a vault"$'\n'"apex=ok"$'\n'"gone=unreachable"$'\n'"plain=not a vault" ]
}

@test "no ~/vaults is no vaults; OVM_VAULTS_HOME moves it, from the environment or ovm.local.env" {
  run ovm ls
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  mkdir -p notes/one
  printf 'id: dddddddddd\n' > notes/one/ovm.yml
  OVM_VAULTS_HOME="$HOME/notes" run ovm ls
  [ "$output" = "one"$'\t'"dddddddddd"$'\t'"ok"$'\t'"~/notes/one" ]
  mkdir -p .config/ovm
  echo 'OVM_VAULTS_HOME=~/notes' > .config/ovm/ovm.local.env
  run ovm path one
  [ "$output" = "$HOME/notes/one" ]
  run ovm new two
  [ -f notes/two/ovm.yml ]
  [ ! -e vaults ]
}

@test "scan, remove and prune are gone, and nothing is written under ~/.local/state/ovm/vaults" {
  vault a
  local cmd
  for cmd in scan remove rm prune; do
    run ovm "$cmd" a
    [ "$status" -eq 64 ]
  done
  run ovm ls --stale
  [ "$status" -eq 64 ]
  ovm ls >/dev/null
  ovm docs >/dev/null
  (cd vaults/a && ovm path >/dev/null && ovm docs >/dev/null)
  ovm new b >/dev/null
  [ ! -e "$XDG_STATE_HOME/ovm/vaults" ]
}

@test "path: the vault you are in, one by name, id or id prefix; an entry that is not a usable vault exits 3" {
  vault a
  local id="$VID"
  mkdir -p vaults/a/deep/er
  cd vaults/a/deep/er
  run ovm path
  [ "$output" = "$HOME/vaults/a" ]
  cd "$HOME"
  run ovm path a
  [ "$output" = "$HOME/vaults/a" ]
  run ovm path "$id"
  [ "$output" = "$HOME/vaults/a" ]
  run ovm path "${id:0:4}"
  [ "$output" = "$HOME/vaults/a" ]
  run ovm path "${id:0:3}"
  [ "$status" -eq 1 ]
  run ovm path
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a vault"* ]]
  mkdir vaults/plain
  run ovm path plain
  [ "$status" -eq 3 ]
  [[ "$output" == "$HOME/vaults/plain"*"plain is not a vault"* ]]
  ln -s nowhere vaults/gone
  run ovm path gone
  [ "$status" -eq 3 ]
  [[ "$output" == *"gone is unreachable"* ]]
}

@test "a linked vault is named by its entry, from inside its real path too" {
  mkdir -p icloud/apex vaults
  ln -s ../icloud/apex vaults/apex
  ovm init vaults/apex >/dev/null
  doc icloud/apex/a.md aaaaaaaaaa Note
  cd icloud/apex
  run ovm docs
  [[ "$output" == "aaaaaaaaaa"$'\t'*$'\t'"apex" ]]
  cd "$HOME/vaults/apex"
  run ovm path
  [ "$output" = "$HOME/icloud/apex" ]
  run ovm path aaaaaaaaaa
  [ "$output" = "$HOME/icloud/apex/a.md" ]
}

@test "an ovm.yml outside ~/vaults: commands in it say to link it there" {
  mkdir loose
  printf 'id: eeeeeeeeee\n' > loose/ovm.yml
  cd loose
  run ovm path
  [ "$status" -eq 1 ]
  [[ "$output" == *"~/loose is not in ~/vaults: link it there"* ]]
  run ovm validate
  [ "$status" -eq 1 ]
  run ovm docs
  [ "$status" -eq 1 ]
}

@test "an ambiguous id prefix exits 2 and lists the candidates" {
  mkdir -p vaults/x vaults/y
  printf 'id: aaaaaaaaab\n' > vaults/x/ovm.yml
  printf 'id: aaaaaaaaac\n' > vaults/y/ovm.yml
  run ovm path aaaa
  [ "$status" -eq 2 ]
  [[ "$output" == *"~/vaults/x"* && "$output" == *"~/vaults/y"* ]]
}

@test "a package's links: entry puts a vault stored elsewhere in ~/vaults, as a relative link" {
  # What stack/obsidian's layer in the person's repository declares (linker 02's src: entry),
  # applied the way ppm applies it: lib/anfs/manifest.sh's plan, then anfs_link_one
  local icloud="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/apex"
  mkdir -p "$icloud" "$BATS_TEST_TMPDIR/layer/home"
  printf 'id: ffffffffff\n' > "$icloud/ovm.yml"
  cat > "$BATS_TEST_TMPDIR/layer/package.yml" <<'YML'
version: 0.1.0
links:
  - src: ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/apex
    dest: vaults/apex
    platforms: [macos]
YML
  run bash -c '
    source "$1/link.sh"; source "$1/manifest.sh"
    rows=$(anfs_manifest_read "$2/package.yml") || exit 1
    anfs_manifest_plan "$rows" "$2/home" macos || { printf "%s\n" "$ANFS_MF_ERR"; exit 1; }
    [ -z "$ANFS_MF_INVALID" ] || { printf "invalid: %s\n" "$ANFS_MF_INVALID"; exit 1; }
    while IFS="	" read -r dest src; do
      [ -n "$dest" ] || continue
      anfs_link_one "$src" "$HOME/$dest" || exit 1
      echo "$dest -> $src"
    done <<< "$ANFS_MF_SRCS"' _ "$HOME/.local/lib/anfs" "$BATS_TEST_TMPDIR/layer"
  [ "$status" -eq 0 ]
  [ "$output" = "vaults/apex -> $icloud" ]
  [ "$(readlink vaults/apex)" = "../Library/Mobile Documents/iCloud~md~obsidian/Documents/apex" ]
  run ovm ls
  [ "$output" = "apex"$'\t'"ffffffffff"$'\t'"ok"$'\t'"~/Library/Mobile Documents/iCloud~md~obsidian/Documents/apex" ]
  run ovm path apex
  [ "$output" = "$icloud" ]
}

@test "the options every tool takes, --version, and an unknown command" {
  run ovm --version
  [[ "$output" == ovm\ * ]]
  run ovm help
  [[ "$output" == *"link <add|remove|list|apply|validate>"* ]]
  [[ "$output" == *"list, ls "* ]]
  [[ "$output" == *"new <name>"* ]]
  [[ "$output" == *"-d, --debug"* ]]
  [[ "$output" == *"~/vaults (OVM_VAULTS_HOME)"* ]]
  [[ "$output" != *scan* && "$output" != *prune* && "$output" != *egistry* ]]
  run ovm nope
  [ "$status" -eq 64 ]
}

@test "a tab press: commands once with their aliases, a vault by its entry, options after a -" {
  vault a
  ln -s nowhere vaults/gone
  run ovm __complete ""
  [[ "$output" == *"list"$'\t'"The entries of ~/vaults: the vaults (alias: ls)"* ]]
  ! grep -qE '^(ls|rm)	' <<< "$output"
  run ovm __complete path ""
  [ "$output" = "a"$'\t'"~/vaults/a"$'\n'"gone"$'\t'"~/vaults/gone" ]
  run ovm __complete link ""
  [[ "$output" == *"remove"$'\t'*"(alias: rm)"* ]]
  run ovm __complete link add ""
  [ "$output" = ":dirs" ]
  run ovm __complete link add "-"
  [[ "$output" == *"--to"$'\t'* && "$output" == *"--as"$'\t'* ]]
  # A tab press writes nothing
  rm -rf "$XDG_STATE_HOME"
  (cd vaults/a && ovm __complete "" >/dev/null)
  [ ! -e "$XDG_STATE_HOME" ]
}

@test "ovm config: list, set and get on a temp home (core's lib/anfs/config.sh)" {
  [[ -f "$HOME/.local/lib/anfs/config.sh" ]] || skip "this core's lib/anfs has no config.sh"
  mkdir -p "$XDG_CONFIG_HOME/ovm"
  cp "$BATS_TEST_DIRNAME/../home/.config/ovm/ovm.env" "$XDG_CONFIG_HOME/ovm/"
  run "$OVM" config list
  [ "$status" -eq 0 ]
  [[ "$output" == *"OVM_PROBE_SECONDS"$'\t'"3"$'\t'"default"* ]]
  run "$OVM" config set OVM_PROBE_SECONDS=9
  [ "$status" -eq 0 ]
  grep -qx "OVM_PROBE_SECONDS=9" "$XDG_CONFIG_HOME/ovm/ovm.local.env"
  run "$OVM" config get OVM_PROBE_SECONDS
  [ "$output" = "9" ]
}
