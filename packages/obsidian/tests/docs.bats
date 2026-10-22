#!/usr/bin/env bats
# Documents: listing them, finding one by id whatever its path, and checking them against the
# vault's vocabulary (vault.yml).
# Run: bats packages/obsidian/tests/

load helper
setup() {
  ovm_setup
  vault notes
  doc vaults/notes/prd/one.md aaaaaaaaaa PRD "The first"
  doc vaults/notes/prd/two.md bbbbbbbbbb PRD "The second"
  doc vaults/notes/adr/why.md cccccccccc ADR "Why: a decision"
}

@test "docs lists id, type, title, space and path for the vault you are in" {
  cd vaults/notes
  run ovm docs
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "cccccccccc"$'\t'"ADR"$'\t'"Why: a decision"$'\t'"-"$'\t'"~/vaults/notes/adr/why.md"$'\t'"notes" ]
  [[ "${lines[1]}" == "aaaaaaaaaa"$'\t'"PRD"$'\t'"The first"* ]]
}

@test "docs: a DIR narrows it, --type filters, and outside a vault it is every vault" {
  vault other
  doc vaults/other/x.md dddddddddd Note
  run ovm docs ./vaults/notes/prd
  [ "${#lines[@]}" -eq 2 ]
  run ovm docs "$HOME/vaults/notes/prd"
  [ "${#lines[@]}" -eq 2 ]
  run ovm docs other
  [ "$output" = "dddddddddd"$'\t'"Note"$'\t'"A title"$'\t'"-"$'\t'"~/vaults/other/x.md"$'\t'"other" ]
  run ovm docs nope
  [ "$status" -eq 1 ]
  run ovm docs --type ADR
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == cccccccccc* ]]
  run ovm docs
  [ "${#lines[@]}" -eq 4 ]
  [[ "$output" == *"dddddddddd"*"other" ]]
  run ovm docs "$HOME"
  [ "$status" -eq 1 ]
}

@test "docs skips hidden directories, node_modules, index.md and log.md" {
  doc vaults/notes/.obsidian/plugin.md eeeeeeeeee Note
  doc vaults/notes/node_modules/pkg/readme.md ffffffffff Note
  doc vaults/notes/index.md gggggggggg Note
  doc vaults/notes/prd/log.md hhhhhhhhhh Note
  run ovm docs notes
  [ "${#lines[@]}" -eq 3 ]
}

@test "a document with frontmatter and no id is listed with an empty id; one with none is not" {
  file vaults/notes/draft.md "---\ntype: Note\ntitle: Draft\n---\ntext\n"
  file vaults/notes/plain.md "# Just markdown\n"
  run ovm docs notes --json
  [ "$status" -eq 0 ]
  run yq -p json -r '.[] | select(.title == "Draft") | .id' <<< "$output"
  [ "$output" = "null" ]
  run ovm docs notes
  [ "${#lines[@]}" -eq 4 ]
  [[ "$output" != *"plain.md"* ]]
}

@test "the space of a document is the vault space it is in; docs VAULT/SPACE lists one" {
  mkdir -p vaults/notes/spaces/product vaults/notes/spaces/ops
  doc vaults/notes/spaces/product/a.md dddddddddd Note
  doc vaults/notes/spaces/product/deep/b.md eeeeeeeeee Note
  doc vaults/notes/spaces/ops/c.md ffffffffff Note
  # A file directly under spaces/ is in no space
  doc vaults/notes/spaces/top.md gggggggggg Note
  cd vaults/notes
  run ovm docs --type Note
  [ "${#lines[@]}" -eq 4 ]
  [[ "${lines[0]}" == "ffffffffff"$'\t'*$'\t'"ops"$'\t'* ]]
  [[ "${lines[1]}" == "dddddddddd"$'\t'*$'\t'"product"$'\t'* ]]
  [[ "${lines[2]}" == "eeeeeeeeee"$'\t'*$'\t'"product"$'\t'* ]]
  [[ "${lines[3]}" == "gggggggggg"$'\t'*$'\t'"-"$'\t'* ]]
  cd "$HOME"
  run ovm docs notes/product
  [ "${#lines[@]}" -eq 2 ]
  run ovm docs notes/nope
  [ "$status" -eq 1 ]
  # A custom spaces_path
  yq -i '.spaces_path = "areas"' vaults/notes/vault.yml
  mkdir -p vaults/notes/areas/home
  doc vaults/notes/areas/home/h.md hhhhhhhhhh Note
  run ovm docs notes --type Note
  [[ "$output" == *"hhhhhhhhhh"*$'\t'"home"$'\t'* ]]
  [[ "$output" == *"dddddddddd"*$'\t'"-"$'\t'* ]]
}

@test "docs --to: the vault spaces links.yml links into a wsm space, across vaults" {
  vault other
  mkdir -p vaults/notes/spaces/product vaults/other/spaces/product vaults/other/spaces/misc
  doc vaults/notes/spaces/product/a.md dddddddddd Note
  doc vaults/other/spaces/product/b.md eeeeeeeeee Note
  doc vaults/other/spaces/misc/c.md ffffffffff Note
  links "- vault: notes\n  space: product\n  to: [anfs-dev]\n- vault: other\n  space: product\n  to: anfs-dev\n  as: other\n- vault: other\n  space: misc\n  to: [lgat]\n"
  cd vaults/notes
  run ovm docs --to anfs-dev
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == "dddddddddd"$'\t'*$'\t'"product"$'\t'*$'\t'"notes" ]]
  [[ "${lines[1]}" == "eeeeeeeeee"$'\t'*$'\t'"product"$'\t'*$'\t'"other" ]]
  run ovm docs --to lgat/
  [ "${#lines[@]}" -eq 1 ]
  run ovm docs --to nowhere
  [ "$status" -eq 0 ]
  [ "$output" = "ovm: no vault space is linked into nowhere (~/.config/ovm/links.yml): ovm space link <vault>/<space> nowhere" ] || [[ "$output" == *"no vault space is linked into nowhere"* && "${#lines[@]}" -eq 1 ]]
  # A place and --to together is a usage error
  run ovm docs notes --to anfs-dev
  [ "$status" -eq 64 ]
}

@test "a document's space is the deepest linked vault space holding it; --space takes a path and what is below it" {
  vault other
  mkdir -p vaults/notes/spaces/anfs/product/deep vaults/notes/spaces/anfs/inbox vaults/notes/spaces/ops vaults/other/spaces/anfs
  doc vaults/notes/spaces/anfs/product/p.md pppppppppp Note
  doc vaults/notes/spaces/anfs/product/deep/q.md qqqqqqqqqq Note
  doc vaults/notes/spaces/anfs/inbox/i.md iiiiiiiiii Note
  doc vaults/notes/spaces/anfs/a.md kkkkkkkkkk Note
  doc vaults/notes/spaces/ops/o.md oooooooooo Note
  doc vaults/other/spaces/anfs/x.md xxxxxxxxxx Note
  # space <id>: what docs says of it
  sp() { ovm docs --json "$@" | yq -p json -r '.[] | .id + " " + (.space // "-")' | sort | tr '\n' ' '; }
  # Nothing linked: the first folder under spaces/
  [ "$(sp notes --type Note)" = "iiiiiiiiii anfs kkkkkkkkkk anfs oooooooooo ops pppppppppp anfs qqqqqqqqqq anfs " ]
  # anfs/product linked (anywhere): it and what is below it
  links "- vault: notes\n  space: anfs/product\n  to: [nowhere]\n"
  [ "$(sp notes --type Note)" = "iiiiiiiiii anfs kkkkkkkkkk anfs oooooooooo ops pppppppppp anfs/product qqqqqqqqqq anfs/product " ]
  # The deepest linked wins; another vault's links are not this one's
  links "- vault: notes\n  space: anfs/product\n  to: [nowhere]\n- vault: notes\n  space: anfs/product/deep\n  to: x\n- vault: other\n  space: anfs/inbox\n  to: x\n"
  [ "$(sp notes --type Note)" = "iiiiiiiiii anfs kkkkkkkkkk anfs oooooooooo ops pppppppppp anfs/product qqqqqqqqqq anfs/product/deep " ]
  run ovm show qqqqqqqqqq --json
  run yq -p json -r .space <<< "$output"
  [ "$output" = "anfs/product/deep" ]
  # --space: the path and everything below it, by whole parts
  [ "$(sp notes --space anfs)" = "iiiiiiiiii anfs kkkkkkkkkk anfs pppppppppp anfs/product qqqqqqqqqq anfs/product/deep " ]
  [ "$(sp notes --space anfs/product/)" = "pppppppppp anfs/product qqqqqqqqqq anfs/product/deep " ]
  [ "$(sp notes --space anfs/prod)" = "" ]
  # Across vaults outside one; in the vault you are in; with a DIR
  [ "$(sp --space anfs --type Note | wc -w | tr -d ' ')" = 10 ]
  cd vaults/notes
  [ "$(sp --space ops)" = "oooooooooo ops " ]
  [ "$(sp ./spaces/anfs/product/deep --space anfs)" = "qqqqqqqqqq anfs/product/deep " ]
  [ "$(sp ./spaces/ops --space anfs)" = "" ]
  run ovm docs --space ../x
  [ "$status" -eq 64 ]
  run ovm docs --space .hidden
  [ "$status" -eq 64 ]
  # A vault space by its path as the argument
  [ "$(sp notes/anfs/product)" = "pppppppppp anfs/product qqqqqqqqqq anfs/product/deep " ]
  # --to and --space together: the linked spaces, narrowed
  links "- vault: notes\n  space: anfs\n  to: [acme]\n- vault: notes\n  space: anfs/product\n  to: [acme]\n  as: apex\n"
  [ "$(sp --to acme --space anfs/product)" = "pppppppppp anfs/product qqqqqqqqqq anfs/product " ]
  [ "$(sp --to acme | wc -w | tr -d ' ')" = 8 ]
}

@test "spaces_path: . — the first folder at the root is a document's space; a file at the root has none" {
  yq -i '.spaces_path = "."' vaults/notes/vault.yml
  doc vaults/notes/top.md tttttttttt Note
  cd vaults/notes
  run ovm docs
  [[ "$output" == *"aaaaaaaaaa"$'\t'"PRD"$'\t'"The first"$'\t'"prd"$'\t'* ]]
  [[ "$output" == *"tttttttttt"$'\t'"Note"$'\t'"A title"$'\t'"-"$'\t'* ]]
  run ovm docs --space adr
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == "cccccccccc"* ]]
  run ovm docs notes/prd
  [ "${#lines[@]}" -eq 2 ]
  # The vocabulary of a space at the root
  yq -i '.spaces.prd.required = ["owner"]' vault.yml
  run ovm validate
  [[ "$output" == *"prd/one.md: missing required key: owner"* ]]
  [[ "$output" != *"adr/why.md: missing required key: owner"* ]]
  [[ "$output" != *"vault.yml:"* ]]
}

@test "validate: a deeper vault space's vocabulary, the deepest entry of spaces: holding the document" {
  mkdir -p vaults/notes/spaces/anfs/product vaults/notes/spaces/anfs/inbox
  file vaults/notes/spaces/anfs/product/p.md "---\nid: pppppppppp\ntype: Note\n---\n"
  file vaults/notes/spaces/anfs/inbox/i.md "---\nid: iiiiiiiiii\ntype: Note\n---\n"
  yq -i '.spaces.anfs.required = ["area"] | .spaces["anfs/product"].required = ["owner"] | .spaces["a/../b"] = {}' vaults/notes/vault.yml
  cd vaults/notes
  run ovm validate
  [[ "$output" == *"spaces/anfs/product/p.md: missing required key: owner"* ]]
  [[ "$output" != *"spaces/anfs/product/p.md: missing required key: area"* ]]
  [[ "$output" == *"spaces/anfs/inbox/i.md: missing required key: area"* ]]
  [[ "$output" == *"vault.yml: spaces.a/../b: a vault space is a folder's path"* ]]
}

@test "docs skips what vault.yml's exclude: names: a directory, a pattern across /, a file pattern" {
  doc vaults/notes/_templates/t.md iiiiiiiiii Note
  doc vaults/notes/prd/drafts/d.md jjjjjjjjjj Note
  doc vaults/notes/adr/old/drafts/e.md kkkkkkkkkk Note
  doc vaults/notes/adr/x.excalidraw.md llllllllll Note
  doc vaults/notes/.trash/gone.md mmmmmmmmmm Note
  # The template excludes _templates
  run ovm docs notes
  [ "${#lines[@]}" -eq 6 ]
  [[ "$output" != *iiiiiiiiii* && "$output" != *mmmmmmmmmm* ]]
  yq -i '.exclude = ["_templates/", "*/drafts", "*.excalidraw.md"]' vaults/notes/vault.yml
  run ovm docs notes
  [ "${#lines[@]}" -eq 3 ]
  [[ "$output" != *jjjjjjjjjj* && "$output" != *kkkkkkkkkk* && "$output" != *llllllllll* ]]
  # No exclude at all: hidden directories are still skipped (init's two templates are documents then)
  yq -i 'del(.exclude)' vaults/notes/vault.yml
  run ovm docs notes
  [ "${#lines[@]}" -eq 9 ]
  [[ "$output" != *mmmmmmmmmm* ]]
  # validate and path go through the same walk
  yq -i '.exclude = ["*/drafts"]' vaults/notes/vault.yml
  run ovm path jjjjjjjjjj
  [ "$status" -eq 1 ]
  cd vaults/notes
  run ovm validate
  [[ "$output" == *"7 document(s)"* ]]   # init's two templates among them
}

@test "quoted titles lose their quotes, and CRLF files read the same" {
  file vaults/notes/q.md "---\r\nid: \"iiiiiiiiii\"\r\ntype: 'Note'\r\ntitle: \"Quoted: yes\"\r\n---\r\nbody\r\n"
  run ovm docs notes --type Note
  [ "$output" = "iiiiiiiiii"$'\t'"Note"$'\t'"Quoted: yes"$'\t'"-"$'\t'"~/vaults/notes/q.md"$'\t'"notes" ]
}

@test "path and show find a document by id from anywhere, after it moved too" {
  run ovm path bbbbbbbbbb
  [ "$output" = "$HOME/vaults/notes/prd/two.md" ]
  mkdir vaults/notes/archive
  mv vaults/notes/prd/two.md "vaults/notes/archive/renamed two.md"
  run ovm path bbbbbbbbbb
  [ "$output" = "$HOME/vaults/notes/archive/renamed two.md" ]
  run ovm show bbbbbbbbbb
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "---" ]
  [[ "$output" == *"# Body of bbbbbbbbbb"* ]]
  run ovm show bbbbbbbbbb --body
  [[ "$output" != *"type: PRD"* ]]
  [[ "$output" == *"# Body of bbbbbbbbbb"* ]]
}

@test "show: an unknown id exits 1; an id in two documents exits 2 and names both" {
  run ovm show zzzzzzzzzz
  [ "$status" -eq 1 ]
  vault other
  doc vaults/other/copy.md aaaaaaaaaa PRD
  run ovm show aaaaaaaaaa
  [ "$status" -eq 2 ]
  [[ "$output" == *"vaults/notes/prd/one.md"* && "$output" == *"vaults/other/copy.md"* ]]
}

@test "an id only in a document's body is not that document's id" {
  file vaults/notes/mention.md "---\nid: jjjjjjjjjj\ntype: Note\n---\nsee\nid: aaaaaaaaaa\n"
  run ovm path aaaaaaaaaa
  [ "$output" = "$HOME/vaults/notes/prd/one.md" ]
}

@test "show --json: id, vault, path, space, the frontmatter as data, the body as text" {
  mkdir -p vaults/notes/spaces/product
  mv vaults/notes/prd/one.md vaults/notes/spaces/product/one.md
  file vaults/notes/spaces/product/one.md "---\nid: aaaaaaaaaa\ntype: PRD\ntags: [a, b]\n---\nLine \"one\"\n\ttabbed\n"
  run ovm show aaaaaaaaaa --json
  [ "$status" -eq 0 ]
  local json="$output"
  run yq -p json -r '[.id, .vault, .vault_id, .path, .space, .frontmatter.tags[1]] | join("|")' <<< "$json"
  [ "$output" = "aaaaaaaaaa|notes|$VID|$HOME/vaults/notes/spaces/product/one.md|product|b" ]
  run yq -p json -r '.body' <<< "$json"
  [ "${lines[0]}" = 'Line "one"' ]
  [ "${lines[1]}" = $'\ttabbed' ]
  run ovm show cccccccccc --json
  run yq -p json -r '.space' <<< "$output"
  [ "$output" = "null" ]
}

# --- validate -----------------------------------------------------------------------------

@test "validate: a clean vault has no findings" {
  cd vaults/notes
  run ovm validate
  [ "$status" -eq 0 ]
  [ "$output" = "3 document(s), 0 finding(s)" ]
}

@test "validate reports no frontmatter, an open block, bad YAML, and missing required keys" {
  file vaults/notes/plain.md "# No frontmatter\n"
  file vaults/notes/open.md "---\nid: kkkkkkkkkk\ntype: Note\n\nnever closed\n"
  file vaults/notes/bad.md "---\nid: llllllllll\ntype: [unclosed\n---\n"
  file vaults/notes/empty.md "---\n---\nbody\n"
  file vaults/notes/notype.md "---\nid: mmmmmmmmmm\ntype:\n---\n"
  cd vaults/notes
  run ovm validate
  [ "$status" -eq 0 ]
  [[ "$output" == *"plain.md: no frontmatter"* ]]
  [[ "$output" == *"open.md: the frontmatter is not closed"* ]]
  [[ "$output" == *"bad.md: the frontmatter does not parse as YAML"* ]]
  [[ "$output" == *"empty.md: missing required key: type"* ]]
  [[ "$output" == *"empty.md: missing required key: id"* ]]
  [[ "$output" == *"notype.md: missing required key: type"* ]]
  [[ "$output" == *"8 document(s), 6 finding(s)"* ]]
}

@test "validate --strict exits 1 on any finding, 0 on none" {
  cd vaults/notes
  run ovm validate --strict
  [ "$status" -eq 0 ]
  file vaults/notes/plain.md "text\n"
  run ovm validate --strict
  [ "$status" -eq 1 ]
}

@test "validate: required is the vault's, merged with the space's (default [type, id])" {
  mkdir -p vaults/notes/spaces/product
  file vaults/notes/spaces/product/p.md "---\nid: nnnnnnnnnn\ntype: Note\n---\n"
  yq -i '.required = ["type", "id", "status"] | .spaces.product.required = ["owner", "id"]' vaults/notes/vault.yml
  cd vaults/notes
  run ovm validate
  [[ "$output" == *"prd/one.md: missing required key: status"* ]]
  [[ "$output" != *"prd/one.md: missing required key: owner"* ]]
  [[ "$output" == *"spaces/product/p.md: missing required key: status"* ]]
  [[ "$output" == *"spaces/product/p.md: missing required key: owner"* ]]
  [[ "$output" == *"5 finding(s)"* ]]
  # No required: at all is the default; an empty one requires nothing
  yq -i 'del(.required) | del(.spaces)' "$HOME/vaults/notes/vault.yml"
  file "vaults/notes/x.md" "---\ntitle: x\n---\n"
  run ovm validate
  [[ "$output" == *"x.md: missing required key: type"* && "$output" == *"x.md: missing required key: id"* ]]
  yq -i '.required = []' "$HOME/vaults/notes/vault.yml"
  run ovm validate
  [[ "$output" == *"0 finding(s)"* ]]
}

@test "validate: kinds are the allowed types, and a kind may require more keys" {
  yq -i '.kinds = {"PRD": {}, "Note": {}, "decision": {"required": ["status"]}}' vaults/notes/vault.yml
  file vaults/notes/full.md "---\nid: nnnnnnnnnn\ntype: decision\nstatus: accepted\n---\n"
  file vaults/notes/bare.md "---\nid: oooooooooo\ntype: decision\n---\n"
  cd vaults/notes
  run ovm validate
  [[ "$output" == *"adr/why.md: type 'ADR' is not one of: Note PRD decision"* ]]
  [[ "$output" == *"bare.md: missing required key for a decision: status"* ]]
  [[ "$output" != *"full.md"* && "$output" != *"prd/one.md"* ]]
  [[ "$output" == *"2 finding(s)"* ]]
  # A space's kinds add to the vault's, and replace one of the same name
  mkdir -p spaces/product
  file vaults/notes/spaces/product/d.md "---\nid: pppppppppp\ntype: decision\n---\n"
  file vaults/notes/spaces/product/a.md "---\nid: qqqqqqqqqq\ntype: ADR\n---\n"
  yq -i '.spaces.product.kinds = {"ADR": {}, "decision": {}}' vault.yml
  run ovm validate
  [[ "$output" != *"spaces/product/"* ]]
}

@test "validate: fields have their type; a list allows those values; an unknown type is said once" {
  yq -i '.fields = {"n": "number", "b": "bool", "d": "date", "t": "datetime", "l": "list", "s": "string", "status": ["draft", "done"], "x": "colour"}' vaults/notes/vault.yml
  file vaults/notes/good.md "---\nid: nnnnnnnnnn\ntype: Note\nn: 1.5\nb: true\nd: 2026-10-22\nt: 2026-10-22T10:00:00Z\nl: [a]\ns: text\nstatus: draft\nx: red\n---\n"
  file vaults/notes/quoted.md "---\nid: oooooooooo\ntype: Note\nd: \"2026-10-22\"\nt: \"2026-10-22 10:00\"\nstatus: [draft, done]\n---\n"
  file vaults/notes/bad.md "---\nid: pppppppppp\ntype: Note\nn: many\nb: yes please\nd: 22/10/2026\nt: 2026-10-22\nl: one\ns: [a, b]\nstatus: [draft, nope]\nx: blue\n---\n"
  file vaults/notes/bad2.md "---\nid: qqqqqqqqqq\ntype: Note\nstatus: gone\n---\n"
  cd vaults/notes
  run ovm validate
  [[ "$output" == *"vault.yml: fields.x: unknown type 'colour'"* ]]
  [ "$(grep -c "unknown type" <<< "$output")" -eq 1 ]
  [[ "$output" != *"good.md"* && "$output" != *"quoted.md"* ]]
  [[ "$output" == *"bad.md: n is not a number: many"* ]]
  [[ "$output" == *"bad.md: b is not a bool: yes please"* ]]
  [[ "$output" == *"bad.md: d is not a date: 22/10/2026"* ]]
  [[ "$output" == *"bad.md: t is not a datetime: 2026-10-22"* ]]
  [[ "$output" == *"bad.md: l is not a list: one"* ]]
  [[ "$output" == *"bad.md: s is not a string"* ]]
  [[ "$output" == *"bad.md: status: 'nope' is not one of: draft done"* ]]
  [[ "$output" == *"bad2.md: status: 'gone' is not one of: draft done"* ]]
  [[ "$output" == *"9 finding(s)"* ]]
}

@test "validate: tags, in the frontmatter (a list or a string) and inline, listed or under a listed one" {
  yq -i '.tags = ["idea", "project", "go"]' vaults/notes/vault.yml
  file vaults/notes/a.md "---\nid: nnnnnnnnnn\ntype: Note\ntags: [idea, project/x, stray]\n---\n#go now, and #project/y/z\nnot#tag here, see #wild.\n"
  file vaults/notes/b.md "---\nid: oooooooooo\ntype: Note\ntags: idea other\n---\n\n\`\`\`\n#fenced\n\`\`\`\nsome \`#inline\` code\n# A heading\n"
  mkdir -p vaults/notes/spaces/product
  file vaults/notes/spaces/product/c.md "---\nid: pppppppppp\ntype: Note\n---\n#linker and #idea and #wsm\n"
  yq -i '.spaces.product.tags = ["linker"]' vaults/notes/vault.yml
  cd vaults/notes
  run ovm validate
  [[ "$output" == *"a.md: tag 'stray' is not in the vocabulary"* ]]
  [[ "$output" == *"a.md: tag 'wild' is not in the vocabulary"* ]]
  [[ "$output" == *"b.md: tag 'other' is not in the vocabulary"* ]]
  [[ "$output" == *"spaces/product/c.md: tag 'wsm' is not in the vocabulary"* ]]
  [[ "$output" != *"fenced"* && "$output" != *"'inline'"* && "$output" != *"'tag'"* && "$output" != *"linker"* ]]
  [[ "$output" == *"4 finding(s)"* ]]
  # A space's tags are that space's only
  file vaults/notes/d.md "---\nid: qqqqqqqqqq\ntype: Note\n---\n#linker\n"
  run ovm validate
  [[ "$output" == *"d.md: tag 'linker' is not in the vocabulary"* ]]
}

@test "validate: go is a built-in tag, allowed whether vault.yml lists it or not; go/x is not" {
  yq -i '.tags = ["idea"]' vaults/notes/vault.yml
  file vaults/notes/a.md "---\nid: nnnnnnnnnn\ntype: Note\ntags: [go]\n---\n- [ ] ship it #go #idea\n#go/x\n"
  cd vaults/notes
  run ovm validate --strict
  [ "$status" -eq 1 ]
  [[ "$output" != *"tag 'go' "* ]]
  [[ "$output" == *"a.md: tag 'go/x' is not in the vocabulary"* ]]
  [[ "$output" == *"1 finding(s)"* ]]
  ovm help | grep -q "ovm validate always allows the tag go"
}

@test "validate: vault.yml's own findings, the old keys with what replaced them" {
  mkdir -p vaults/notes/spaces/product
  yq -i '.links = [{"source": "a", "target": "b"}] | .profile = {"required": ["type"]} | .items = {"exclude": ["x"]} | .colour = "red"
    | .spaces.product.bogus = 1 | .spaces.gone = {} | .kinds.Note.extra = 1' vaults/notes/vault.yml
  cd vaults/notes
  run ovm validate
  [[ "$output" == *"vault.yml: links: is not read: link a vault space with ovm space link, declared in ~/.config/ovm/links.yml"* ]]
  [[ "$output" == *"vault.yml: profile: is not read: its required is required:, its types are kinds:"* ]]
  [[ "$output" == *"vault.yml: items: is not read: what to skip is exclude:"* ]]
  [[ "$output" == *"vault.yml: unknown key 'colour'"* ]]
  [[ "$output" == *"vault.yml: spaces.product: unknown key 'bogus'"* ]]
  [[ "$output" == *"vault.yml: spaces.gone: no folder spaces/gone"* ]]
  [[ "$output" == *"vault.yml: kinds.Note: unknown key 'extra'"* ]]
  [ "$(grep -c '^vault.yml: ' <<< "$output")" -eq 7 ]
  # Nothing reads them: profile's required changes nothing
  [[ "$output" != *"missing required key"* ]]
  yq -i '.spaces_path = "../up"' vault.yml
  run ovm validate
  [[ "$output" == *"vault.yml: spaces_path may not leave the vault (..): ../up"* ]]
}

@test "validate reports an id used twice, on both, even when one is outside PATH" {
  doc vaults/notes/adr/copy.md aaaaaaaaaa ADR
  cd vaults/notes
  run ovm validate
  [[ "$output" == *"adr/copy.md: duplicate id aaaaaaaaaa (also prd/one.md)"* || "$output" == *"prd/one.md: duplicate id aaaaaaaaaa (also adr/copy.md)"* ]]
  [[ "$output" == *"2 finding(s)"* ]]
  run ovm validate adr
  [[ "$output" == *"adr/copy.md: duplicate id aaaaaaaaaa"* ]]
  [[ "$output" == *"2 document(s), 1 finding(s)"* ]]
}

@test "validate --fix mints a missing id and changes nothing else" {
  file vaults/notes/new.md "---\ntype: Note\ntitle: New\n---\n\nBody stays.\n"
  file vaults/notes/blank.md "---\nid:\ntype: Note\n---\nBody.\n"
  file vaults/notes/plain.md "no frontmatter\n"
  cd vaults/notes
  run ovm validate --fix
  [ "$status" -eq 0 ]
  [[ "$output" == *"new.md: minted id "* ]]
  [[ "$output" == *"2 id(s) minted"* ]]
  [[ "$output" == *"plain.md: no frontmatter"* ]]
  [[ "$output" != *"missing required key"* ]]
  # A new id goes last in the frontmatter; the lines that were there are as they were
  run cat new.md
  [ "${lines[0]}" = "---" ]
  [ "${lines[1]}" = "type: Note" ]
  [ "${lines[2]}" = "title: New" ]
  [[ "${lines[3]}" =~ ^id:\ [a-z2-7]{10}$ ]]
  [ "${lines[4]}" = "---" ]
  [ "${lines[5]}" = "Body stays." ]
  run cat blank.md
  [[ "${lines[1]}" =~ ^id:\ [a-z2-7]{10}$ ]]
  [ "${lines[2]}" = "type: Note" ]
  [ "$(cat plain.md)" = "no frontmatter" ]
  # Minted once: the id is never changed after
  local id
  id=$(sed -n 4p new.md)
  ovm validate --fix >/dev/null
  [ "$(sed -n 4p new.md)" = "$id" ]
}

@test "validate takes one file, and --json lists the findings" {
  file vaults/notes/plain.md "text\n"
  run ovm validate vaults/notes/plain.md
  [ "$output" = "plain.md: no frontmatter"$'\n'"1 document(s), 1 finding(s)" ]
  run ovm validate vaults/notes --json
  [ "$status" -eq 0 ]
  run yq -p json -r '.[0] | .path + ": " + .finding' <<< "$output"
  [ "$output" = "plain.md: no frontmatter" ]
  rm vaults/notes/plain.md
  run ovm validate vaults/notes --json
  [ "$output" = "[]" ]
}
