#!/usr/bin/env bats
# chorus: the frontmatter of chorus documents (units and their plans), listed and shown.
# Run: bats packages/obsidian/tests/chorus.bats </dev/null

load helper
setup() {
  chorus_setup
  # A unit with plans, one without, a plan's log, and files that are not documents
  file units/alpha.md "---\nobjective: The first unit\nstatus: plan 01 written\n---\n\n# Alpha\n"
  file units/alpha/01-one/plan.md "# Plan 01\n"
  file units/alpha/01-one/log.md "---\nplan: alpha/01-one\njob: alpha-01\ndate: 2026-10-23\nsummary: Built the one\n---\n# Log\n"
  file units/alpha/02-two/plan.md "---\n---\n# Plan 02\n"
  file units/alpha/README.md "# not a plan\n"
  file units/beta.md "---\nobjective: \"The second: quoted\"\nstatus: Merged 2026-10-23\n---\n"
  file units/plain.md "# No frontmatter\n"
  file units/open.md "---\nstatus: never closed\n"
  file units/.hidden/x.md "---\nstatus: hidden\n---\n"
  file units/node_modules/y.md "---\nstatus: vendored\n---\n"
}

@test "list: the documents directly in a directory, by name: NAME STATUS PLANS OBJECTIVE" {
  run chorus list units
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "alpha"$'\t'"plan 01 written"$'\t'"2"$'\t'"The first unit" ]
  [ "${lines[1]}" = "beta"$'\t'"Merged 2026-10-23"$'\t'"-"$'\t'"The second: quoted" ]
  cd units
  run chorus ls
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == alpha$'\t'* ]]
  run chorus ls ./
  [[ "${lines[0]}" == alpha$'\t'* ]]
}

@test "list -r: the documents below too, named by their path; hidden and node_modules skipped" {
  run chorus ls -r units
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[0]}" = "alpha"$'\t'"plan 01 written"$'\t'"2"$'\t'"The first unit" ]
  # a log has no objective: its summary
  [ "${lines[1]}" = "alpha/01-one/log"$'\t'"-"$'\t'"-"$'\t'"Built the one" ]
  [ "${lines[2]}" = "alpha/02-two/plan"$'\t'"-"$'\t'"-"$'\t'"-" ]
  [[ "${lines[3]}" == beta$'\t'* ]]
  [[ "$output" != *hidden* && "$output" != *vendored* && "$output" != *never* ]]
}

@test "list FILE: that document; a file that is not one, or no such path, is exit 1" {
  run chorus ls units/alpha.md
  [ "$status" -eq 0 ]
  [ "$output" = "alpha"$'\t'"plan 01 written"$'\t'"2"$'\t'"The first unit" ]
  run chorus ls units/plain.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a chorus document"* ]]
  run chorus ls units/open.md
  [ "$status" -eq 1 ]
  [[ "$output" == *"not closed"* ]]
  run chorus ls nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"nope: no such file or directory"* ]]
}

@test "list of a directory with no documents prints nothing, and [] with --json" {
  mkdir -p empty
  run chorus ls empty
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run chorus ls empty --json
  [ "$output" = "[]" ]
}

@test "list --status: a substring of the status, any case; given twice, either" {
  run chorus ls units --status merged
  [ "$output" = "beta"$'\t'"Merged 2026-10-23"$'\t'"-"$'\t'"The second: quoted" ]
  run chorus ls units -s WRITTEN
  [[ "$output" == alpha$'\t'* && "${#lines[@]}" -eq 1 ]]
  run chorus ls units -s merged -s written
  [ "${#lines[@]}" -eq 2 ]
  run chorus ls -r units -s nothing
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list --json: every frontmatter key, and name, path (the whole path) and plans" {
  run chorus ls -r units --json
  [ "$status" -eq 0 ]
  [[ "$output" == '[{"name":"alpha","path":"'"$HOME"'/units/alpha.md","plans":"2","objective":"The first unit","status":"plan 01 written"},'* ]]
  [[ "$output" == *'{"name":"alpha/01-one/log","path":"'"$HOME"'/units/alpha/01-one/log.md","plans":null,"plan":"alpha/01-one","job":"alpha-01","date":"2026-10-23","summary":"Built the one"}'* ]]
  [[ "$output" == *'{"name":"alpha/02-two/plan","path":"'"$HOME"'/units/alpha/02-two/plan.md","plans":null}'* ]]
  [[ "$output" == *'"objective":"The second: quoted"'*']' ]]
  cd units
  run chorus --json ls alpha.md
  [ "$output" = '[{"name":"alpha","path":"'"$HOME"'/units/alpha.md","plans":"2","objective":"The first unit","status":"plan 01 written"}]' ]
}

@test "frontmatter: quotes, comments, nulls, lists, block scalars, continued values, CRLF" {
  file d/shapes.md '---\r
dq: "say \\"hi\\" # not a comment"\r
sq: '"'"'it'"'"''"'"'s'"'"'\r
plain: a value # a comment\r
url: http://x.y/z#frag\r
none: null\r
tilde: ~\r
empty:\r
flow: [a, "b c", d]\r
block:\r
  - one\r
  - "two"\r
folded: >-\r
  first line\r
  second line\r
literal: |\r
  line one\r
  line two\r
continued: starts here\r
  and goes on\r
# a comment line\r
nested:\r
  inner: value\r
dup: first\r
dup: second\r
---\r
'
  run chorus ls d --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"dq":"say \"hi\" # not a comment"'* ]]
  [[ "$output" == *'"sq":"it'"'"'s"'* ]]
  [[ "$output" == *'"plain":"a value"'* ]]
  [[ "$output" == *'"url":"http://x.y/z#frag"'* ]]
  [[ "$output" == *'"none":null,"tilde":null,"empty":null'* ]]
  [[ "$output" == *'"flow":["a","b c","d"]'* ]]
  [[ "$output" == *'"block":["one","two"]'* ]]
  [[ "$output" == *'"folded":"first line second line"'* ]]
  [[ "$output" == *'"literal":"line one\nline two"'* ]]
  [[ "$output" == *'"continued":"starts here and goes on"'* ]]
  [[ "$output" == *'"nested":"inner: value"'* ]]
  [[ "$output" == *'"dup":"second"}]' ]]
  [[ "$output" != *'"dup":"first"'* ]]
}

@test "frontmatter closed by ... is a document; a key that collides with name, path or plans is ours" {
  file d/dots.md "---\nstatus: done\nname: theirs\n...\n"
  run chorus ls d --json
  [ "$output" = '[{"name":"dots","path":"'"$HOME"'/d/dots.md","plans":null,"status":"done"}]' ]
}

@test "on a terminal STATUS is cut at 40 characters and each line at the terminal's width" {
  file t/long.md "---\nstatus: $(printf 'x%.0s' {1..60})\nobjective: $(printf 'o%.0s' {1..100})\n---\n"
  # widths are in characters, so the locale is UTF-8's (C.UTF-8: on macOS and Debian alike)
  LC_ALL=C.UTF-8 ANFS_TABLE=aligned COLUMNS=80 run chorus ls t
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "NAME  STATUS                                    PLANS  OBJECTIVE" ]
  [ "${lines[1]}" = "long  $(printf 'x%.0s' {1..39})…  -      $(printf 'o%.0s' {1..24})…" ]
  # piped, nothing is cut
  COLUMNS=80 run chorus ls t
  [ "$output" = "long"$'\t'"$(printf 'x%.0s' {1..60})"$'\t'"-"$'\t'"$(printf 'o%.0s' {1..100})" ]
}

@test "show: every field of one document, its plans, by file or by its path without .md" {
  file units/gamma.md "---\nobjective: Third\ntags: [a, b]\nnotes: |\n  one\n  two\nstatus:\n---\n"
  mkdir -p units/gamma/01-x
  run chorus show units/gamma.md
  [ "$status" -eq 0 ]
  [ "$output" = "name: gamma
path: ~/units/gamma.md
plans: 1
  - 01-x
objective: Third
tags:
  - a
  - b
notes: |
  one
  two
status:" ]
  run chorus show units/beta
  [ "$output" = "name: beta
path: ~/units/beta.md
objective: The second: quoted
status: Merged 2026-10-23" ]
  run chorus show units/gamma --json
  [ "$output" = '{"name":"gamma","path":"'"$HOME"'/units/gamma.md","plans":"1","objective":"Third","tags":["a","b"],"notes":"one\ntwo","status":null}' ]
}

@test "show: no such document, or not one, is exit 1; no argument is a usage error" {
  run chorus show units/nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"units/nope: no such document"* ]]
  run chorus show units/plain.md
  [ "$status" -eq 1 ]
  run chorus show units/open
  [ "$status" -eq 1 ]
  run chorus show
  [ "$status" -eq 64 ]
  [[ "$output" == *"usage: chorus show <path>"* ]]
}

@test "the options every tool takes: help, --version, an unknown option or command" {
  run chorus help
  [ "$status" -eq 0 ]
  [[ "$output" == *"list, ls [-r] [-s TEXT] [path]"* ]]
  [[ "$output" == *"show <path>"* ]]
  [[ "$output" == *"-d, --debug"* ]]
  [[ "$output" == *"A chorus document is"* ]]
  run chorus --version
  [[ "$output" == "chorus "[0-9]* ]]
  run chorus ls --bogus
  [ "$status" -eq 64 ]
  [[ "$output" == *"unknown option '--bogus'"* ]]
  run chorus nope
  [ "$status" -eq 64 ]
  run chorus ls a b
  [ "$status" -eq 64 ]
}
