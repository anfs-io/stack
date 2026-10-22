#!/usr/bin/env bats
# Tasks: the open `- [ ]` lines of a vault, a vault space, a DIR or the vault spaces linked into a
# wsm space, with exactly the ten keys user/pjm's `pull` reads.
# Run: bats packages/obsidian/tests/

load helper
setup() {
  ovm_setup
  command -v jq >/dev/null 2>&1 || skip "jq is not installed"
  vault notes
}

# The tasks of <scope...> as JSON, then a jq filter over them: tj <filter> [ovm tasks args...]
tj() {
  local filter="$1"; shift
  ovm tasks "$@" --json | jq -c "$filter"
}

# A file in the test HOME, written as is (no escapes): put <path relative to ~> < content
put() {
  mkdir -p "$(dirname "$HOME/$1")"
  cat > "$HOME/$1"
}

@test "one open task per form: - * + 1. 1) indented by spaces and a tab, in a callout" {
  printf '# Forms\n- [ ] dash\n* [ ] star\n+ [ ] plus\n1. [ ] dot\n2) [ ] paren\n  - [ ] two spaces\n\t- [ ] tab\n> [!todo] Callout\n> - [ ] in callout\n>> - [ ] nested quote\n' |
    put vaults/notes/forms.md
  run tj 'map([.line, .text])' notes
  [ "$status" -eq 0 ]
  [ "$output" = '[["2","dash"],["3","star"],["4","plus"],["5","dot"],["6","paren"],["7","two spaces"],["8","tab"],["10","in callout"],["11","nested quote"]]' ]
  # The table: SPACE FILE LINE TEXT
  run ovm tasks notes
  [ "${lines[0]}" = "-"$'\t'"forms.md"$'\t'"2"$'\t'"dash" ]
}

@test "not tasks: done, other boxes, malformed, empty, frontmatter, fenced code (four opened, three do not close)" {
  put vaults/notes/not.md <<'EOF'
---
id: aaaaaaaaaa
list:
- [ ] in frontmatter
---
- [x] done
- [X] Done
- [-] cancelled
- [/] started
- [] empty box
-[ ] no space
- [ ]
- [ ]   
- [ ] the real one
```
- [ ] in backticks
```
~~~ text
- [ ] in tildes
~~~
- [ ] after the fences
````
- [ ] in four
```
- [ ] still in four
EOF
  run tj 'map([.line, .text, .doc])' notes
  [ "$status" -eq 0 ]
  [ "$output" = '[["14","the real one","aaaaaaaaaa"],["21","after the fences","aaaaaaaaaa"]]' ]
}

@test "a frontmatter block that never closes is body: its tasks are listed, doc null; CRLF reads the same" {
  printf -- '---\n- [ ] after an unclosed block\n' | put vaults/notes/open.md
  printf -- '---\r\nid: bbbbbbbbbb\r\n---\r\n## Head ##\r\n- [ ] crlf #t\r\n' | put vaults/notes/crlf.md
  run tj 'map([.file, .line, .text, .doc, .section, .tags])' notes
  [ "$output" = '[["crlf.md","5","crlf #t","bbbbbbbbbb","Head",["t"]],["open.md","2","after an unclosed block",null,null,[]]]' ]
}

@test "section: the nearest heading, closing #s stripped; null before the first; a # line in a fence is not one" {
  put vaults/notes/sections.md <<'EOF'
- [ ] before any heading
## Closing ##
- [ ] under closing
```
# not a heading
```
- [ ] after the fence
### C# #
- [ ] sharp
#tag is not a heading
- [ ] still sharp
EOF
  run tj 'map([.text, .section])' notes
  [ "$output" = '[["before any heading",null],["under closing","Closing"],["after the fence","Closing"],["sharp","C#"],["still sharp","C#"]]' ]
}

@test "parent: under an open task, a done one, two levels; a sibling is not; a plain bullet stops it; tabs count to 4" {
  printf '%s\n' \
    '- [ ] open parent' \
    '  - [ ] child of open' \
    '    - [ ] grandchild' \
    '  - [ ] sibling child' \
    '- [x] done parent' \
    '  - [ ] child of done' \
    '- [ ] top two' \
    '- plain bullet' \
    '  - [ ] under bullet' \
    '- [ ] top' \
    '    - [ ] four-space parent' \
    $'\t\t- [ ] tab child' \
    $'\t- [ ] tab sibling' \
    '' \
    'A paragraph' \
    '  - [ ] after a paragraph' | put vaults/notes/parents.md
  run tj 'map([.text, .parent])' notes
  [ "$output" = '[["open parent",null],["child of open","open parent"],["grandchild","child of open"],["sibling child","open parent"],["child of done","done parent"],["top two",null],["under bullet",null],["top",null],["four-space parent","top"],["tab child","four-space parent"],["tab sibling","top"],["after a paragraph",null]]' ]
}

@test "tags: several, nested, once each, not in inline code, not #123; the text keeps them" {
  printf '%s\n' '- [ ] several #one #two/sub and `#code` and #123 and #one again #go, x#no' | put vaults/notes/tags.md
  run tj 'map([.tags, .text])' notes
  [ "$output" = '[[["one","two/sub","go"],"several #one #two/sub and `#code` and #123 and #one again #go, x#no"]]' ]
}

@test "doc: the frontmatter id, null without one; index.md and log.md are read, their doc null" {
  printf -- '---\nid: cccccccccc\ntype: Note\n---\n- [ ] in a doc\n' | put vaults/notes/doc.md
  printf -- '- [ ] plain\n' | put vaults/notes/plain.md
  printf -- '---\nid: dddddddddd\n---\n- [ ] in the index\n' | put vaults/notes/index.md
  printf -- '- [ ] in the log\n' | put vaults/notes/sub/log.md
  run tj 'map([.file, .doc])' notes
  [ "$output" = '[["doc.md","cccccccccc"],["index.md",null],["plain.md",null],["sub/log.md",null]]' ]
}

@test "space: <vault>/<space> under spaces_path, null at the root and directly in spaces/; a custom spaces_path" {
  printf -- '- [ ] p\n' | put vaults/notes/spaces/product/deep/plan.md
  printf -- '- [ ] top\n' | put vaults/notes/spaces/top.md
  printf -- '- [ ] root\n' | put vaults/notes/root.md
  vault other
  yq -i '.spaces_path = "areas/"' vaults/other/vault.yml
  printf -- '- [ ] o\n' | put vaults/other/areas/ops/x.md
  printf -- '- [ ] s\n' | put vaults/other/spaces/ops/y.md
  run tj 'map([.vault, .file, .space])'
  [ "$output" = '[["notes","root.md",null],["notes","spaces/product/deep/plan.md","notes/product"],["notes","spaces/top.md",null],["other","areas/ops/x.md","other/ops"],["other","spaces/ops/y.md",null]]' ]
}

@test "scopes: in a vault, every vault outside one, <vault>, <vault>/<space>, a bare space in a vault, DIR" {
  vault other
  printf -- '- [ ] n root\n' | put vaults/notes/a.md
  printf -- '- [ ] n product\n' | put vaults/notes/spaces/product/b.md
  printf -- '- [ ] o root\n' | put vaults/other/c.md
  run tj 'map(.text)'
  [ "$output" = '["n root","n product","o root"]' ]
  run tj 'map(.text)' other
  [ "$output" = '["o root"]' ]
  run tj 'map(.text)' notes/product
  [ "$output" = '["n product"]' ]
  run tj 'map(.text)' ./vaults/notes/spaces
  [ "$output" = '["n product"]' ]
  cd vaults/notes/spaces
  run tj 'map(.text)'
  [ "$output" = '["n root","n product"]' ]
  run tj 'map([.text, .file])' product
  [ "$output" = '[["n product","spaces/product/b.md"]]' ]
  # A bare name that is a vault is the vault
  run tj 'map(.text)' other
  [ "$output" = '["o root"]' ]
  run ovm tasks nospace
  [ "$status" -eq 1 ]
  cd "$HOME"
  run ovm tasks product
  [ "$status" -eq 1 ]
  run ovm tasks notes/nope
  [ "$status" -eq 1 ]
  run ovm tasks "$HOME"
  [ "$status" -eq 1 ]
  # No tasks: 0 and an empty list
  run ovm tasks other/none
  [ "$status" -eq 1 ]
  mkdir -p vaults/other/spaces/none
  run ovm tasks other/none --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "--space: the vault spaces links.yml links into a wsm space, across vaults; one space in two" {
  vault other
  mkdir -p vaults/notes/spaces/product vaults/other/spaces/product vaults/other/spaces/misc
  printf -- '- [ ] n product\n' | put vaults/notes/spaces/product/a.md
  printf -- '- [ ] o product\n' | put vaults/other/spaces/product/b.md
  printf -- '- [ ] o misc\n' | put vaults/other/spaces/misc/c.md
  printf -- '- [ ] n root\n' | put vaults/notes/d.md
  links "- vault: notes\n  space: product\n  to: [anfs-dev, lgat]\n- vault: other\n  space: product\n  to: anfs-dev\n  as: other\n- vault: other\n  space: misc\n  to: [lgat]\n"
  run tj 'map([.space, .text])' --space anfs-dev
  [ "$status" -eq 0 ]
  [ "$output" = '[["notes/product","n product"],["other/product","o product"]]' ]
  run tj 'map([.space, .text])' --space lgat/
  [ "$output" = '[["notes/product","n product"],["other/misc","o misc"]]' ]
  # The wsm space need not be installed (links.yml is read, not wsm)
  [ ! -s "$WSM_LEVELS" ]
}

@test "--space: no entry is 0, empty, and a warning naming ovm space link; missing vault or folder warned and skipped; with an argument 64" {
  mkdir -p vaults/notes/spaces/product
  printf -- '- [ ] n product\n' | put vaults/notes/spaces/product/a.md
  links "- vault: notes\n  space: product\n  to: [anfs-dev]\n- vault: gone\n  space: x\n  to: [anfs-dev]\n- vault: notes\n  space: nofolder\n  to: [anfs-dev]\n"
  run ovm tasks --space nowhere --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"no vault space is linked into nowhere"*"ovm space link <vault>/<space> nowhere"* ]]
  [ "${lines[-1]}" = "[]" ]
  run ovm tasks --space anfs-dev
  [ "$status" -eq 0 ]
  [[ "$output" == *"gone/x skipped: no vault gone"* ]]
  [[ "$output" == *"notes/nofolder skipped: no folder"* ]]
  [[ "$output" == *"n product"* ]]
  run ovm tasks notes --space anfs-dev
  [ "$status" -eq 64 ]
}

@test "exclude: a pruned directory's tasks are not listed; .obsidian and .trash never are" {
  printf -- '- [ ] kept\n' | put vaults/notes/a.md
  printf -- '- [ ] generated\n' | put vaults/notes/_generated/t.md
  printf -- '- [ ] template\n' | put vaults/notes/_templates/x.md
  printf -- '- [ ] hidden\n' | put vaults/notes/.obsidian/x.md
  printf -- '- [ ] trash\n' | put vaults/notes/.trash/x.md
  yq -i '.exclude = ["_generated", "_templates"]' vaults/notes/vault.yml
  run tj 'map(.text)' notes
  [ "$output" = '["kept"]' ]
}

@test "--json: exactly pjm's ten keys on every element; tags a list; empty fields null; sorted by vault, file, line" {
  local vid
  vault other
  printf -- '---\nid: eeeeeeeeee\n---\n# H\n- [ ] one #a\n  - [ ] two\n' | put vaults/notes/spaces/s/b.md
  printf -- '- [ ] three\n' | put vaults/notes/a.md
  printf -- '- [ ] four\n' | put vaults/other/a.md
  run tj 'map(keys) | unique'
  [ "$output" = '[["doc","file","line","parent","section","space","tags","text","vault","vault_id"]]' ]
  run tj 'map(.tags | type) | unique'
  [ "$output" = '["array"]' ]
  run tj 'map([.vault, .file, .line])'
  [ "$output" = '[["notes","a.md","1"],["notes","spaces/s/b.md","5"],["notes","spaces/s/b.md","6"],["other","a.md","1"]]' ]
  run tj '.[0] | [.doc, .space, .section, .parent, .tags]'
  [ "$output" = '[null,null,null,null,[]]' ]
  vid=$(yq -r .id vaults/notes/vault.yml)
  run tj ".[1] | [.vault_id == \"$vid\", .doc, .space, .section, .parent, .tags]"
  [ "$output" = '[true,"eeeeeeeeee","notes/s","H",null,["a"]]' ]
  run tj '.[2] | [.parent, .section]'
  [ "$output" = '["one #a","H"]' ]
}

@test "the contract: pjm's pull normalisation reads back the same values" {
  printf -- '---\nid: ffffffffff\n---\n## Work\n- [ ] ship it #go #x\n  - [ ] sub #go\n' | put vaults/notes/spaces/product/p.md
  ovm tasks --json > "$BATS_TEST_TMPDIR/src.json"
  run jq -c -s --arg tag go -f "$BATS_TEST_DIRNAME/pjm-pull.jq" "$BATS_TEST_TMPDIR/src.json"
  [ "$status" -eq 0 ]
  run jq -c --arg v "$VID" 'map([.vault_id == $v, .vault, .file, .line, .doc, .space, .section, .parent, .tags, .go, .text])' <<< "$output"
  [ "$output" = '[[true,"notes","spaces/product/p.md",5,"ffffffffff","notes/product","Work","",["go","x"],true,"ship it #x"],[true,"notes","spaces/product/p.md",6,"ffffffffff","notes/product","Work","ship it #x",["go"],true,"sub"]]' ]
}

@test "speed: 500 files are listed in under 2 seconds (one awk, not one per file)" {
  [[ -n "${EPOCHREALTIME:-}" ]] || skip "needs bash 5's EPOCHREALTIME"
  local i start end
  mkdir -p vaults/notes/many
  for (( i = 0; i < 500; i++ )); do
    printf -- '---\nid: x%09d\n---\n# H\n- [ ] task %d #t\n' "$i" "$i" > "vaults/notes/many/f$i.md"
  done
  start=$EPOCHREALTIME
  run ovm tasks notes --json
  end=$EPOCHREALTIME
  [ "$status" -eq 0 ]
  [ "$(jq length <<< "$output")" -eq 500 ]
  awk -v s="$start" -v e="$end" 'BEGIN { exit !(e - s < 2) }'
}

@test "help lists tasks; it completes vaults and spaces" {
  run ovm help
  [[ "$output" == *"tasks"*"open tasks"* ]]
  mkdir -p vaults/notes/spaces/product
  run ovm __complete tasks ""
  [[ "$output" == *"notes"* ]]
  [[ "$output" == *"notes/product"* ]]
}
