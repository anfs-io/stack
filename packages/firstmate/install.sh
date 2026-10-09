#!/usr/bin/env bash
# firstmate — the repo is checked out at meta.firstmate.ref (package.yml); bump ref and reinstall to upgrade

FIRSTMATE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/firstmate"

# Read meta.firstmate.<key> from this package's package.yml
_fm_meta() { yq -r ".meta.firstmate.$1" "$pkg_dir/package.yml"; }

post_install() {
  local repo ref dir="$FIRSTMATE_HOME/repo"
  repo=$(_fm_meta repo) ref=$(_fm_meta ref)
  if [[ ! -d "$dir/.git" ]]; then
    git clone --quiet "$repo" "$dir" || { ppm_fail "firstmate: cannot clone $repo"; return; }
  fi
  if ! git -C "$dir" cat-file -e "$ref^{commit}" 2>/dev/null; then
    git -C "$dir" fetch --quiet origin || { ppm_fail "firstmate: cannot fetch $repo"; return; }
  fi
  git -C "$dir" checkout --quiet --detach "$ref" || ppm_fail "firstmate: cannot check out $ref"
}

pre_remove() {
  command -v firstmate &>/dev/null && firstmate down || true
}

post_remove() {
  rm -rf "$FIRSTMATE_HOME"
}
