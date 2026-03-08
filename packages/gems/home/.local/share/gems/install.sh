#!/usr/bin/env bash
set -euo pipefail

GEMS_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Install foundation first (others depend on it), then the rest
install_repo() {
  local repo_dir="$1"
  [[ -f "$repo_dir/Gemfile" ]] || return 0
  echo "Installing gems in $(basename "$repo_dir")..."
  cd "$repo_dir"
  bundle install --quiet
  bundle config set --local bin bin
  mkdir -p bin
  # generate binstubs for gems with executables
  for gemspec in "$repo_dir"/*/*.gemspec; do
    [[ -f "$gemspec" ]] || continue
    local gem_dir="$(dirname "$gemspec")"
    if [[ -d "$gem_dir/exe" ]] && ls "$gem_dir/exe"/* &>/dev/null; then
      local gem_name="$(basename "$gem_dir")"
      bundle binstubs "$gem_name" --force 2>&1 | grep -v "has no executables" || true
      chmod +x "$gem_dir"/exe/*
    fi
  done
  [[ -d bin ]] && chmod +x bin/* 2>/dev/null || true
}

# Foundation first
install_repo "$GEMS_ROOT/rjayroach"

# Then the rest (no ordering needed between these)
for repo_dir in "$GEMS_ROOT"/*/; do
  [[ -d "$repo_dir" ]] || continue
  [[ "$(basename "$repo_dir")" == "rjayroach" ]] && continue
  install_repo "$repo_dir"
done
