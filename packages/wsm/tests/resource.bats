#!/usr/bin/env bats
# The `wsm:` package.yml key — the handler this package contributes to ppm's installer.
# ppm's core libs are sourced directly, with the tracker redirected into the test temp dir.
# Run: bats packages/wsm/tests/resource.bats

load helper

setup() {
  wsm_setup

  # ppm's core libs, from the sibling ppm repo clone; PPM_CORE_LIB overrides for other layouts
  local core="${PPM_CORE_LIB:-$BATS_TEST_DIRNAME/../../../../ppm/packages/system/home/.local/lib/ppm}"
  [ -f "$core/core.sh" ] || skip "ppm core libs not found at $core"

  PPM_INSTALLED_DIR="$BATS_TEST_TMPDIR/installed"
  BIN_DIR="$BATS_TEST_DIRNAME/../home/.local/bin"
  export PPM_INSTALLED_DIR BIN_DIR
  mkdir -p "$PPM_INSTALLED_DIR"

  # shellcheck source=/dev/null
  source "$core/core.sh"
  source "$core/packages.sh"
  source "$BATS_TEST_DIRNAME/../home/.local/lib/ppm/wsm.sh"

  PKG="$BATS_TEST_TMPDIR/pkg"
  mkdir -p "$PKG"
}

messages() { cat "$PPM_MSG_FILE" 2>/dev/null; }

# A workspace already in place, as stow would leave it
stowed_space() {
  mkdir -p "$HOME/$1/.wsm"
  printf '3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c\n' > "$HOME/$1/.wsm/id"
}

@test "a wsm entry with repo_url clones and prepares" {
  local space inner
  inner=$(mkbare inner)
  mkdir -p "$BATS_TEST_TMPDIR/src/space/.wsm"
  cat > "$BATS_TEST_TMPDIR/src/space/.wsm/resources" <<YML
resources:
  - url: $inner
    path: repos/inner
YML
  space=$(mkbare space)

  cat > "$PKG/package.yml" <<YML
version: 0.1.0
wsm:
  - repo_url: $space
    path: spaces/demo
YML
  run ppm_resource_wsm demo mypkg "$PKG"
  [ "$status" -eq 0 ]
  [ -d "$HOME/spaces/demo/.git" ]
  [ -f "$HOME/spaces/demo/repos/inner/README" ]
  [ "$(meta_resources demo mypkg wsm)" = "spaces/demo" ]
}

@test "repo_url is optional: a stowed workspace is taken as already in place" {
  local inner
  inner=$(mkbare inner)
  stowed_space spaces/rjayroach
  cat > "$HOME/spaces/rjayroach/.wsm/resources" <<YML
resources:
  - url: $inner
    path: repos/inner
YML
  cat > "$PKG/package.yml" <<'YML'
version: 0.1.0
wsm:
  - path: spaces/rjayroach
YML
  run ppm_resource_wsm demo mypkg "$PKG"
  [ "$status" -eq 0 ]
  # Not cloned over, and its resources were prepared
  [ ! -e "$HOME/spaces/rjayroach/.git" ]
  [ -f "$HOME/spaces/rjayroach/repos/inner/README" ]
  [ "$(meta_resources demo mypkg wsm)" = "spaces/rjayroach" ]
  # The stowed id survived: it is what identifies the workspace across machines
  [ "$(cat "$HOME/spaces/rjayroach/.wsm/id")" = "3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c" ]
}

@test "a stowed workspace with no resources file is still registered" {
  stowed_space spaces/bare
  cat > "$PKG/package.yml" <<'YML'
version: 0.1.0
wsm:
  - path: spaces/bare
YML
  run ppm_resource_wsm demo mypkg "$PKG"
  [ "$status" -eq 0 ]
  [ "$(meta_resources demo mypkg wsm)" = "spaces/bare" ]
  run "$BIN_DIR/wsm" ls
  [[ "$output" == *"bare"* ]]
}

@test "no repo_url and nothing stowed is an error that names the package's omission" {
  cat > "$PKG/package.yml" <<'YML'
version: 0.1.0
wsm:
  - path: spaces/missing
YML
  run ppm_resource_wsm demo mypkg "$PKG"
  [ "$status" -ne 0 ]
  [[ "$output" == *"has no repo_url and nothing is there"* ]]
}

@test "an entry with no path is refused" {
  cat > "$PKG/package.yml" <<'YML'
version: 0.1.0
wsm:
  - repo_url: git@example.com:a/b
YML
  run ppm_resource_wsm demo mypkg "$PKG"
  [ "$status" -ne 0 ]
  [[ "$output" == *"needs a path"* ]]
}

@test "entries are read field by field, so a missing repo_url does not shift the path" {
  local inner
  inner=$(mkbare inner)
  stowed_space spaces/first
  cat > "$PKG/package.yml" <<YML
version: 0.1.0
wsm:
  - path: spaces/first
  - repo_url: $inner
    path: spaces/second
YML
  run ppm_resource_wsm demo mypkg "$PKG"
  [ "$status" -eq 0 ]
  [ -d "$HOME/spaces/second/.git" ]
  [ "$(meta_resources demo mypkg wsm | sort | tr '\n' ' ')" = "spaces/first spaces/second " ]
}

@test "a path escaping \$HOME is refused" {
  cat > "$PKG/package.yml" <<'YML'
version: 0.1.0
wsm:
  - repo_url: git@example.com:a/b
    path: ../escaped
YML
  run ppm_resource_wsm demo mypkg "$PKG"
  [ "$status" -ne 0 ]
  [[ "$output" == *"stay inside it"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/escaped" ]
}

@test "one failing entry does not stop the others" {
  local inner
  inner=$(mkbare inner)
  cat > "$PKG/package.yml" <<YML
version: 0.1.0
wsm:
  - path: spaces/nothing-stowed-here
  - repo_url: $inner
    path: spaces/good
YML
  run ppm_resource_wsm demo mypkg "$PKG"
  [ "$status" -ne 0 ]
  [ -d "$HOME/spaces/good/.git" ]
}

@test "remove without force keeps everything and reports it" {
  stowed_space spaces/keep
  cat > "$PKG/package.yml" <<'YML'
version: 0.1.0
wsm:
  - path: spaces/keep
YML
  ppm_resource_wsm demo mypkg "$PKG"
  force=false
  run ppm_resource_wsm_remove demo mypkg
  [ "$status" -eq 0 ]
  [ -d "$HOME/spaces/keep" ]
  [[ "$(messages)" == *"Left in place: ~/spaces/keep"* ]]
}

@test "remove with force deletes a workspace whose repos are all pushed" {
  local inner
  inner=$(mkbare inner)
  stowed_space spaces/gone
  cat > "$HOME/spaces/gone/.wsm/resources" <<YML
resources:
  - url: $inner
    path: repos/inner
YML
  ppm_resource_wsm demo mypkg "$PKG" 2>/dev/null || true
  cat > "$PKG/package.yml" <<'YML'
version: 0.1.0
wsm:
  - path: spaces/gone
YML
  ppm_resource_wsm demo mypkg "$PKG"
  [ -d "$HOME/spaces/gone/repos/inner" ]

  force=true
  run ppm_resource_wsm_remove demo mypkg
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/spaces/gone" ]
}

@test "remove with force keeps a workspace holding unpushed work, and says which repo" {
  local inner
  inner=$(mkbare inner)
  stowed_space spaces/wip
  cat > "$HOME/spaces/wip/.wsm/resources" <<YML
resources:
  - url: $inner
    path: repos/inner
YML
  cat > "$PKG/package.yml" <<'YML'
version: 0.1.0
wsm:
  - path: spaces/wip
YML
  ppm_resource_wsm demo mypkg "$PKG"
  echo "unsaved" > "$HOME/spaces/wip/repos/inner/WIP.txt"

  force=true
  run ppm_resource_wsm_remove demo mypkg
  [ "$status" -eq 0 ]
  [ -d "$HOME/spaces/wip" ]
  [[ "$(messages)" == *"repos/inner: uncommitted or untracked changes"* ]]
}
