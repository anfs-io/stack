#!/usr/bin/env bash
set -euo pipefail

GEMS_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Generate Gemfile from symlinked gems
echo "Generating Gemfile..."
cat > "$GEMS_ROOT/Gemfile" <<'HEADER'
source "https://rubygems.org"

HEADER

for gemdir in "$GEMS_ROOT"/*/; do
  [[ -L "${gemdir%/}" ]] || continue
  for gemspec in "$gemdir"*.gemspec; do
    [[ -f "$gemspec" ]] || continue
    gem_name="$(basename "$gemspec" .gemspec)"
    echo "gem \"$gem_name\", path: \"$gemdir\"" >> "$GEMS_ROOT/Gemfile"
    break
  done
done

# Bundle install from GEMS_ROOT
echo "Running bundle install..."
cd "$GEMS_ROOT"
bundle install --quiet
bundle config set --local bin bin
mkdir -p bin

# Generate binstubs for gems with executables
for gemdir in "$GEMS_ROOT"/*/; do
  [[ -L "${gemdir%/}" ]] || continue
  if [[ -d "$gemdir/exe" ]] && ls "$gemdir/exe"/* &>/dev/null; then
    gem_name="$(basename "$gemdir")"
    bundle binstubs "$gem_name" --force 2>&1 | grep -v "has no executables" || true
    chmod +x "$gemdir"/exe/*
  fi
done

[[ -d bin ]] && chmod +x bin/* 2>/dev/null || true
