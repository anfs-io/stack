#!/usr/bin/env bats
# ovm init makes a vault workflow ready: the pinned plugins placed as files (downloaded once into
# the cache, sha256-checked), their settings and our templates copied where missing. curl is the
# helper's stub, serving fixture releases; the pins are the helper's fixture plugins.yml beside
# the package's real vault/ skeleton.

load helper
setup() { ovm_setup; }

PINS=(templater-obsidian obsidian-shellcommands obsidian-meta-bind-plugin)
SKELETON=(
  .obsidian/plugins/obsidian-meta-bind-plugin/data.json
  .obsidian/plugins/obsidian-shellcommands/data.json
  .obsidian/plugins/templater-obsidian/data.json
  _templates/note.md
  _templates/task-list.md
)
SHIPPED="$BATS_TEST_DIRNAME/../home/.local/lib/ovm/vault"

# The fixture release's file of a pin: <id> <asset>
served() {
  local spec
  for spec in $FIXTURE_PINS; do
    [[ "${spec%%:*}" == "$1" ]] && { printf '%s\n' "$OVM_RELEASES/${spec#*:}/releases/download/1.0.0/$2"; return; }
  done
  return 1
}

curl_calls() { grep -c . "$CURL_LOG" || true; }

@test "new places the skeleton, the three plugins and enables them, and says the two clicks and the warning" {
  run ovm new notes
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "initialized vault notes ("*") at ~/vaults/notes" ]]
  local v="$VAULTS/notes" f id a
  [ -f "$v/vault.yml" ]
  for f in "${SKELETON[@]}"; do cmp "$SHIPPED/$f" "$v/$f"; done
  for id in "${PINS[@]}"; do
    for a in main.js manifest.json styles.css; do cmp "$(served "$id" "$a")" "$v/.obsidian/plugins/$id/$a"; done
    [[ "$output" == *"placed $id 1.0.0"* ]]
  done
  run yq -p json -o tsv '.' "$v/.obsidian/community-plugins.json"
  [ "$output" = "templater-obsidian	obsidian-shellcommands	obsidian-meta-bind-plugin" ]
  run ovm init "$v"
  [[ "$output" == *"turn on community plugins"* ]]
  [[ "$output" == *'"Trigger Templater on new file creation"'* ]]
  [[ "$output" == *"Shell commands lets a note run commands on this computer"* ]]
  [[ "$output" == *"read"*".obsidian/plugins/obsidian-shellcommands/data.json"* ]]
  [[ "$output" == *"desktop only"* ]]
  # Nothing is left beside the files written
  [ -z "$(find "$v" -name '*.ovm.*' -o -name '*.anfs-copy.*')" ]
  [ -z "$(find "$XDG_CACHE_HOME/ovm" -name '*.part')" ]
}

@test "copy-if-missing: edited settings and templates survive, a deleted one comes back, nothing is downloaded again" {
  ovm new notes >/dev/null
  local v="$VAULTS/notes"
  printf 'mine\n' > "$v/_templates/note.md"
  printf '{"templates_folder": "Mine"}\n' > "$v/.obsidian/plugins/templater-obsidian/data.json"
  rm "$v/_templates/task-list.md"
  : > "$CURL_LOG"
  run ovm init "$v"
  [ "$status" -eq 0 ]
  [ "$(cat "$v/_templates/note.md")" = mine ]
  [ "$(cat "$v/.obsidian/plugins/templater-obsidian/data.json")" = '{"templates_folder": "Mine"}' ]
  cmp "$SHIPPED/_templates/task-list.md" "$v/_templates/task-list.md"
  [[ "$output" == *"copied _templates/task-list.md"* ]]
  [[ "$output" == *"kept 4 files that are yours"* ]]
  [[ "$output" != *placed* ]]
  [[ "$output" == *"templater-obsidian 1.0.0 is there"* ]]
  [ "$(curl_calls)" -eq 0 ]
}

@test "community-plugins.json: another plugin and its order kept, ours not added twice; invalid JSON not written" {
  mkdir -p "$VAULTS/a/.obsidian"
  printf '[\n  "dataview",\n  "obsidian-shellcommands",\n  "calendar"\n]\n' > "$VAULTS/a/.obsidian/community-plugins.json"
  run ovm init "$VAULTS/a"
  [ "$status" -eq 0 ]
  run yq -p json -o tsv '.' "$VAULTS/a/.obsidian/community-plugins.json"
  [ "$output" = "dataview	obsidian-shellcommands	calendar	templater-obsidian	obsidian-meta-bind-plugin" ]
  # Already all there: the file is not rewritten
  printf '["obsidian-meta-bind-plugin","templater-obsidian","obsidian-shellcommands"]' > "$VAULTS/a/.obsidian/community-plugins.json"
  rm -r "$VAULTS/a/.obsidian/plugins/templater-obsidian"
  run ovm init "$VAULTS/a"
  [ "$status" -eq 0 ]
  [ "$(cat "$VAULTS/a/.obsidian/community-plugins.json")" = '["obsidian-meta-bind-plugin","templater-obsidian","obsidian-shellcommands"]' ]

  mkdir -p "$VAULTS/b/.obsidian"
  printf '{"not": "a list"' > "$VAULTS/b/.obsidian/community-plugins.json"
  run ovm init "$VAULTS/b"
  [ "$status" -eq 1 ]
  [[ "$output" == *"community-plugins.json is not a JSON array of plugin ids: not written"* ]]
  [ "$(cat "$VAULTS/b/.obsidian/community-plugins.json")" = '{"not": "a list"' ]
  # The plugins are placed all the same
  [ -f "$VAULTS/b/.obsidian/plugins/templater-obsidian/main.js" ]
}

@test "a plugin already there is left by init; --update brings an older one to the pin, leaves a newer one, names an absent one" {
  mkdir -p "$VAULTS/v"
  plugin_at v templater-obsidian 0.9.0
  printf '{"mine": true}\n' > "$VAULTS/v/.obsidian/plugins/templater-obsidian/data.json"
  plugin_at v obsidian-shellcommands 2.0.0
  run ovm init "$VAULTS/v"
  [ "$status" -eq 0 ]
  [[ "$output" == *"templater-obsidian 0.9.0 is there: left as it is (the pin is 1.0.0"* ]]
  [[ "$output" == *"placed obsidian-meta-bind-plugin 1.0.0"* ]]
  grep -q 0.9.0 "$VAULTS/v/.obsidian/plugins/templater-obsidian/main.js"
  [ "$(cat "$VAULTS/v/.obsidian/plugins/templater-obsidian/data.json")" = '{"mine": true}' ]

  local cp="$VAULTS/v/.obsidian/community-plugins.json" before a
  before=$(cat "$cp")
  rm -r "$VAULTS/v/.obsidian/plugins/obsidian-meta-bind-plugin" "$VAULTS/v/_templates/note.md"
  run ovm init --update "$VAULTS/v"
  [ "$status" -eq 0 ]
  for a in main.js manifest.json styles.css; do
    cmp "$(served templater-obsidian "$a")" "$VAULTS/v/.obsidian/plugins/templater-obsidian/$a"
  done
  [[ "$output" == *"updated templater-obsidian 0.9.0 -> 1.0.0"* ]]
  [[ "$output" == *"Reload app without saving"* ]]
  [ "$(cat "$VAULTS/v/.obsidian/plugins/templater-obsidian/data.json")" = '{"mine": true}' ]
  [[ "$output" == *"obsidian-shellcommands 2.0.0 is newer than the pin (1.0.0): left as it is"* ]]
  grep -q 2.0.0 "$VAULTS/v/.obsidian/plugins/obsidian-shellcommands/main.js"
  [[ "$output" == *"obsidian-meta-bind-plugin is not in this vault: ovm init places it"* ]]
  [ ! -e "$VAULTS/v/.obsidian/plugins/obsidian-meta-bind-plugin" ]
  # Nothing else is touched
  [ "$(cat "$cp")" = "$before" ]
  [ ! -e "$VAULTS/v/_templates/note.md" ]
  # At the pin: nothing to do
  run ovm init --update "$VAULTS/v"
  [[ "$output" == *"templater-obsidian 1.0.0 is at the pin"* ]]
  # The command line
  run ovm init --update --no-plugins "$VAULTS/v"
  [ "$status" -eq 64 ]
  mkdir "$VAULTS/plain"
  run ovm init --update "$VAULTS/plain"
  [ "$status" -eq 3 ]
  [ ! -e "$VAULTS/plain/vault.yml" ]
}

@test "the cache: a second vault downloads nothing, a corrupted file is fetched again, wrong bytes are a checksum mismatch" {
  ovm new a >/dev/null
  [ "$(curl_calls)" -eq 9 ]
  local cache="$XDG_CACHE_HOME/ovm/plugins"
  [ -f "$cache/templater-obsidian/1.0.0/main.js" ]
  : > "$CURL_LOG"
  run ovm new b
  [ "$status" -eq 0 ]
  [ "$(curl_calls)" -eq 0 ]
  [ -f "$VAULTS/b/.obsidian/plugins/obsidian-meta-bind-plugin/main.js" ]

  printf 'corrupt\n' > "$cache/templater-obsidian/1.0.0/main.js"
  run ovm new c
  [ "$status" -eq 0 ]
  [ "$(cat "$CURL_LOG")" = "https://github.com/SilentVoid13/Templater/releases/download/1.0.0/main.js" ]
  cmp "$(served templater-obsidian main.js)" "$VAULTS/c/.obsidian/plugins/templater-obsidian/main.js"
  cmp "$(served templater-obsidian main.js)" "$cache/templater-obsidian/1.0.0/main.js"

  rm "$cache/obsidian-shellcommands/1.0.0/main.js"
  printf 'tampered\n' > "$(served obsidian-shellcommands main.js)"
  run ovm new d
  [ "$status" -eq 69 ]
  [[ "$output" == *"obsidian-shellcommands not placed: checksum mismatch for obsidian-shellcommands main.js: the pin or the release changed"* ]]
  local p="$VAULTS/d/.obsidian/plugins/obsidian-shellcommands"
  [ ! -e "$p/main.js" ] && [ ! -e "$p/manifest.json" ] && [ ! -e "$p/styles.css" ]
  [ -f "$p/data.json" ]   # the skeleton's, copied before
  [ ! -e "$cache/obsidian-shellcommands/1.0.0/main.js" ]
  [ -z "$(find "$cache" -name '*.part')" ]
  [ -f "$VAULTS/d/.obsidian/plugins/templater-obsidian/main.js" ]
  [ -f "$VAULTS/d/.obsidian/plugins/obsidian-meta-bind-plugin/main.js" ]
  run yq -p json -o tsv '.' "$VAULTS/d/.obsidian/community-plugins.json"
  [ "$output" = "templater-obsidian	obsidian-meta-bind-plugin" ]
}

@test "no curl: 69, and vault.yml and the skeleton are there" {
  # A PATH of the commands ovm uses, without curl
  local nb="$BATS_TEST_TMPDIR/nocurl" t
  mkdir -p "$nb"
  for t in bash env yq perl find sed sort mktemp cmp cp mv ln mkdir rm head tr grep dirname readlink \
           cat awk cut wc date uname basename touch chmod ls sha256sum shasum tail id hostname; do
    command -v "$t" >/dev/null 2>&1 && ln -s "$(command -v "$t")" "$nb/$t"
  done
  ln -s "$BATS_TEST_TMPDIR/bin/wsm" "$nb/wsm"
  PATH="$nb" run "$(command -v bash)" "$OVM" new notes
  [ "$status" -eq 69 ]
  [[ "$output" == *"curl is not installed"* ]]
  [ -f "$VAULTS/notes/vault.yml" ]
  [ -f "$VAULTS/notes/_templates/note.md" ]
  [ ! -e "$VAULTS/notes/.obsidian/plugins/templater-obsidian/main.js" ]
  # With curl, init finishes it
  run ovm init "$VAULTS/notes"
  [ "$status" -eq 0 ]
  [ -f "$VAULTS/notes/.obsidian/plugins/templater-obsidian/main.js" ]
}

@test "--no-plugins: the settings and templates, no plugin, no download" {
  run ovm new notes --no-plugins
  [ "$status" -eq 0 ]
  [ -f "$VAULTS/notes/_templates/task-list.md" ]
  [ -z "$(find "$VAULTS/notes" -name main.js)" ]
  [ ! -e "$VAULTS/notes/.obsidian/community-plugins.json" ]
  [ "$(curl_calls)" -eq 0 ]
  [[ "$output" != *"turn on community plugins"* ]]
}

@test "something in the way of the skeleton: nothing of it copied, the plugins still placed, exit 1" {
  mkdir -p "$VAULTS/w/_templates/note.md"
  run ovm init "$VAULTS/w"
  [ "$status" -eq 1 ]
  [[ "$output" == *"settings and templates: nothing copied: in the way: _templates/note.md (a directory)"* ]]
  [ ! -e "$VAULTS/w/_templates/task-list.md" ]
  [ ! -e "$VAULTS/w/.obsidian/plugins/templater-obsidian/data.json" ]
  [ -f "$VAULTS/w/vault.yml" ]
  [ -f "$VAULTS/w/.obsidian/plugins/templater-obsidian/main.js" ]
}

@test "the library missing: 69 with the hint, vault.yml written" {
  rm "$HOME/.local/lib/ovm"
  mkdir -p "$BATS_TEST_TMPDIR/alone"
  cp "$OVM" "$BATS_TEST_TMPDIR/alone/ovm"
  mkdir "$VAULTS" "$VAULTS/notes"
  run "$BATS_TEST_TMPDIR/alone/ovm" init "$VAULTS/notes"
  [ "$status" -eq 69 ]
  [[ "$output" == *"ovm's files are missing: ppm install -f stack/obsidian"* ]]
  [ -f "$VAULTS/notes/vault.yml" ]
  [ ! -e "$VAULTS/notes/_templates" ]
  # Run from the package, the package's own library is found
  rm "$VAULTS/notes/vault.yml"
  run ovm init "$VAULTS/notes" --no-plugins
  [ "$status" -eq 0 ]
  [ -f "$VAULTS/notes/_templates/note.md" ]
}

@test "a Shell commands data.json of the person's is kept, and init says how to add ovm's command" {
  mkdir -p "$VAULTS/apex/.obsidian/plugins/obsidian-shellcommands"
  printf '{"settings_version": "0.23.0", "shell_commands": []}\n' > "$VAULTS/apex/.obsidian/plugins/obsidian-shellcommands/data.json"
  run ovm init "$VAULTS/apex" --json
  [ "$status" -eq 0 ]
  [ "$(cat "$VAULTS/apex/.obsidian/plugins/obsidian-shellcommands/data.json")" = '{"settings_version": "0.23.0", "shell_commands": []}' ]
  run ovm init "$VAULTS/apex"
  [[ "$output" == *"ovm's command is not in them"* ]]
  [[ "$output" == *'New shell command: PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH" ovm validate'* ]]
}

@test "the rendered templates pass validate --strict with init's vault.yml; the skeleton's JSON parses" {
  ovm new notes >/dev/null
  local v="$VAULTS/notes" t f
  for t in note task-list; do
    sed -e 's/^id: <%.*%>$/id: '"$(printf '%-10s' "${t//-/}" | tr ' ' 2 | cut -c1-10)"'/' \
        -e 's/<% tp\.file\.title %>/A '"$t"'/g' "$v/_templates/$t.md" > "$v/$t.md"
    ! grep -q '<%' "$v/$t.md"
  done
  grep -q '^- \[ \] $' "$v/task-list.md"
  grep -q 'command: obsidian-shellcommands:shell-command-ovm-validate' "$v/task-list.md"
  cd "$v"
  run ovm validate --strict
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 document(s)"* ]]
  run ovm docs notes
  [[ "$output" == *"A note"* && "$output" == *"A task-list"* ]]
  while IFS= read -r f; do yq -p json -o json -e . "$f" >/dev/null; done < <(find "$SHIPPED" -name '*.json')
  # The pieces that make the three work together
  [ "$(yq -p json -r '.shell_commands[0].id' "$SHIPPED/.obsidian/plugins/obsidian-shellcommands/data.json")" = ovm-validate ]
  [ "$(yq -p json -r '.settings_version' "$SHIPPED/.obsidian/plugins/obsidian-shellcommands/data.json")" = 0.23.0 ]
  [ "$(yq -p json -r '.folder_templates[0].template' "$SHIPPED/.obsidian/plugins/templater-obsidian/data.json")" = _templates/note.md ]
  [ "$(yq -p json -r '.excludedFolders[0]' "$SHIPPED/.obsidian/plugins/obsidian-meta-bind-plugin/data.json")" = _templates ]
}

@test "--json: placed, updated, kept, copied, steps_left" {
  run ovm new j --json
  [ "$status" -eq 0 ]
  [ "$(yq -p json -r .placed <<< "$output")" = "templater-obsidian obsidian-shellcommands obsidian-meta-bind-plugin" ]
  [ "$(yq -p json -r .updated <<< "$output")" = "" ]
  [ "$(yq -p json -r .kept <<< "$output")" = "" ]
  [[ "$(yq -p json -r .copied <<< "$output")" == *"_templates/note.md"* ]]
  [ "$(yq -p json -r .steps_left <<< "$output")" = "turn-on-community-plugins templater-trigger-on-new-file" ]
  [ "$(yq -p json -r .status <<< "$output")" = initialized ]
  plugin_at j templater-obsidian 0.1.0
  run ovm init --update "$VAULTS/j" --json
  [ "$(yq -p json -r .updated <<< "$output")" = templater-obsidian ]
  [ "$(yq -p json -r .kept <<< "$output")" = "obsidian-shellcommands obsidian-meta-bind-plugin" ]
}
