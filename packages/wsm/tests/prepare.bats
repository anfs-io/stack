#!/usr/bin/env bats
# prepare: cloning what a workspace declares in .wsm/resources.
# Everything clones over file:// from bare repos in the test temp dir — no network.
# Run: bats packages/wsm/tests/prepare.bats

load helper
setup() {
  wsm_setup
  mkdir -p "$HOME/space"
  (cd "$HOME/space" && wsm init >/dev/null)
}

@test "a missing resources file is a no-op, not an error" {
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "it clones every declared repo" {
  local a b
  a=$(mkbare alpha); b=$(mkbare beta)
  resources space <<YML
resources:
  - type: repo
    url: $a
    path: repos/alpha
  - type: repo
    url: $b
    path: repos/beta
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -eq 0 ]
  [[ "$output" == *"cloned repos/alpha"* ]]
  [[ "$output" == *"cloned repos/beta"* ]]
  [[ "$output" == *"2 cloned, 0 present, 0 skipped, 0 failed"* ]]
  [ -f "$HOME/space/repos/alpha/README" ]
  [ -f "$HOME/space/repos/beta/README" ]
}

@test "type defaults to repo" {
  local a
  a=$(mkbare alpha)
  resources space <<YML
resources:
  - url: $a
    path: repos/alpha
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -eq 0 ]
  [ -f "$HOME/space/repos/alpha/README" ]
}

@test "an existing clone is left alone, not pulled" {
  local a
  a=$(mkbare alpha)
  resources space <<YML
resources:
  - url: $a
    path: repos/alpha
YML
  cd "$HOME/space"
  wsm prepare >/dev/null
  echo "local work" > "$HOME/space/repos/alpha/SCRATCH"

  run wsm prepare
  [ "$status" -eq 0 ]
  [[ "$output" == *"present repos/alpha"* ]]
  [[ "$output" == *"0 cloned, 1 present"* ]]
  [ -f "$HOME/space/repos/alpha/SCRATCH" ]
}

@test "a ref is checked out after the clone" {
  local a
  a=$(mkbare alpha other)
  resources space <<YML
resources:
  - url: $a
    path: repos/alpha
    ref: other
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -eq 0 ]
  [ -f "$HOME/space/repos/alpha/BRANCH" ]
}

@test "an unknown type is a warning and a skip, and the rest still run" {
  local a
  a=$(mkbare alpha)
  resources space <<YML
resources:
  - type: link
    url: somewhere
    path: bases/thing
  - url: $a
    path: repos/alpha
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -eq 0 ]
  [[ "$output" == *"unknown resource type 'link'"* ]]
  [[ "$output" == *"1 cloned, 0 present, 1 skipped, 0 failed"* ]]
  [ -f "$HOME/space/repos/alpha/README" ]
}

@test "something in the way that is not a repo fails, and the rest still run" {
  local a b
  a=$(mkbare alpha); b=$(mkbare beta)
  mkdir -p "$HOME/space/repos/alpha"
  echo "not a repo" > "$HOME/space/repos/alpha/stuff"
  resources space <<YML
resources:
  - url: $a
    path: repos/alpha
  - url: $b
    path: repos/beta
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -ne 0 ]
  [[ "$output" == *"in the way and not a git repo: repos/alpha"* ]]
  [[ "$output" == *"1 cloned, 0 present, 0 skipped, 1 failed"* ]]
  [ -f "$HOME/space/repos/beta/README" ]
  [ -f "$HOME/space/repos/alpha/stuff" ]
}

@test "a path that escapes the workspace is refused" {
  resources space <<'YML'
resources:
  - url: file:///nowhere.git
    path: ../escaped
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -ne 0 ]
  [[ "$output" == *"inside the workspace"* ]]
  [ ! -e "$HOME/escaped" ]
}

@test "a failed clone leaves nothing behind" {
  resources space <<'YML'
resources:
  - url: file:///definitely/not/a/repo.git
    path: repos/nope
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -ne 0 ]
  [[ "$output" == *"clone failed"* ]]
  [ ! -e "$HOME/space/repos/nope" ]
}

@test "--dry-run reports but clones nothing" {
  local a
  a=$(mkbare alpha)
  resources space <<YML
resources:
  - url: $a
    path: repos/alpha
YML
  cd "$HOME/space"
  run wsm prepare --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would clone repos/alpha"* ]]
  [ ! -e "$HOME/space/repos/alpha" ]
}

@test ".wsm/resources.yml is accepted too" {
  local a
  a=$(mkbare alpha)
  resources space resources.yml <<YML
resources:
  - url: $a
    path: repos/alpha
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -eq 0 ]
  [ -f "$HOME/space/repos/alpha/README" ]
}

@test "resources are read field by field, so a missing url does not shift the path" {
  local a
  a=$(mkbare alpha)
  resources space <<YML
resources:
  - type: link
    path: bases/thing
  - url: $a
    path: repos/alpha
YML
  cd "$HOME/space"
  run wsm prepare
  [ "$status" -eq 0 ]
  # The link entry has no url; the repo after it must still land at its own path
  [ -f "$HOME/space/repos/alpha/README" ]
  [ ! -e "$HOME/space/bases" ]
}

@test "prepare takes an explicit directory" {
  local a
  a=$(mkbare alpha)
  resources space <<YML
resources:
  - url: $a
    path: repos/alpha
YML
  cd "$HOME"
  run wsm prepare "$HOME/space"
  [ "$status" -eq 0 ]
  [ -f "$HOME/space/repos/alpha/README" ]
}
