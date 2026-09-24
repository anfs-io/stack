#!/usr/bin/env bash
# pde/wsm — teaches ppm the `wsm:` package.yml key
#
# Stowed to ~/.local/lib/ppm/ and sourced by ppm. A function named ppm_resource_<key> makes <key>
# a declared resource: the installer hands it every package that declares one. So a package can be
# nothing but a declaration of the spaces it wants —
#
#   depends: [wsm]
#   wsm:
#     - repo_url: git@github.com:you/rws-space
#       path: spaces/rws
#
# — and installing it clones that repo to ~/spaces/rws, registers it as a workspace, and runs
# `wsm prepare` inside, which clones whatever the space's own .wsm/resources declares.
#
# Note the two different bases for `path`. Here it is relative to $HOME, because this entry
# decides *where a space lives*. Inside .wsm/resources it is relative to the workspace root,
# because that file describes *what is inside one*.

# The stowed wsm, even when ~/.local/bin is not on PATH (cron, sudo -iu, env -i)
_wsm_bin() {
  if command -v wsm >/dev/null 2>&1; then
    printf 'wsm\n'
  elif [[ -x "${BIN_DIR:-$HOME/.local/bin}/wsm" ]]; then
    printf '%s\n' "${BIN_DIR:-$HOME/.local/bin}/wsm"
  else
    return 1
  fi
}

# Usage: ppm_resource_wsm <repo> <package> <package_dir>
ppm_resource_wsm() {
  local repo="$1" pkg="$2" dir="$3" url path target rc=0

  command -v git >/dev/null 2>&1 || { ppm_fail "git is not installed"; return 1; }
  command -v yq >/dev/null 2>&1 || { ppm_fail "yq is not installed"; return 1; }

  while IFS="$(printf '\t')" read -r url path; do
    [[ -n "$url$path" ]] || continue
    if [[ -z "$url" || -z "$path" ]]; then
      ppm_fail "a wsm entry needs both repo_url and path (got url='$url' path='$path')" || true
      rc=1
      continue
    fi
    case "$path" in
      /*|..|../*|*/../*|*/..)
        ppm_fail "wsm path must be relative to \$HOME and stay inside it: $path" || true
        rc=1
        continue
        ;;
    esac

    target="$HOME/$path"
    if [[ -d "$target/.git" ]]; then
      debug "wsm: ~/$path is already a git repo, leaving it alone"
    elif [[ -e "$target" || -L "$target" ]]; then
      ppm_fail "wsm: ~/$path is in the way and is not a git repo" || true
      rc=1
      continue
    else
      echo "  Cloning $url -> ~/$path"
      mkdir -p "$(dirname "$target")"
      if ! git clone -- "$url" "$target"; then
        # Leave nothing half-cloned behind for the next run to trip over
        rm -rf "$target"
        ppm_fail "wsm: could not clone $url" || true
        rc=1
        continue
      fi
    fi

    # Recorded before prepare runs: if prepare fails the clone still exists and remove must know
    meta_add_resource "$repo" "$pkg" wsm "$path"
    _wsm_space_prepare "$target" "$path" || rc=1
  done < <(yq -r '.wsm[]? | [(.repo_url // ""), (.path // "")] | @tsv' "$dir/package.yml")

  return $rc
}

# Register the space, then fill it in from its own .wsm/resources
_wsm_space_prepare() {
  local target="$1" path="$2" bin
  if ! bin=$(_wsm_bin); then
    user_message "wsm is not installed; run 'wsm init && wsm prepare' in ~/$path yourself"
    return 0
  fi
  # init is idempotent and keeps a committed .wsm/id, so a space repo that ships its marker keeps
  # the same identity on every machine
  ( cd "$target" && "$bin" init >/dev/null && "$bin" prepare ) || {
    ppm_fail "wsm prepare failed in ~/$path" || true
    return 1
  }
}

# Usage: ppm_resource_wsm_remove <repo> <package>
#
# A space is mostly other people's repos and your work in them. Without -f nothing is deleted.
# With -f, only what is recoverable from a remote goes: every git repo under the space is checked
# for uncommitted changes, unpushed commits and a missing remote, and anything at risk is kept.
ppm_resource_wsm_remove() {
  local repo="$1" pkg="$2" path target risk line

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    target="$HOME/$path"

    if [[ ! -d "$target" ]]; then
      debug "wsm: ~/$path is already gone"
      continue
    fi
    if ! ${force:-false}; then
      user_message "Left in place: ~/$path (ppm remove -f removes it, if everything in it is pushed)"
      continue
    fi

    risk=$(_wsm_unpushed "$target")
    if [[ -n "$risk" ]]; then
      user_message "Kept ~/$path — work in it is not recoverable from a remote:"
      while IFS= read -r line; do
        [[ -n "$line" ]] && user_message "$line"
      done <<< "$risk"
      continue
    fi

    echo "  Removing ~/$path"
    rm -rf "${target:?}"
  done < <(meta_resources "$repo" "$pkg" wsm)
}

# One line per git repo under <dir> whose contents are not safely on a remote
_wsm_unpushed() {
  local gitpath repo
  # -name .git catches the file form too, as used by worktrees and submodules
  while IFS= read -r gitpath; do
    [[ -n "$gitpath" ]] || continue
    repo="${gitpath%/.git}"
    _wsm_repo_risk "$repo"
  done < <(find "$1" -maxdepth 6 -name .git -print 2>/dev/null)
}

_wsm_repo_risk() {
  local repo="$1" why=""
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0

  # A space's own resources are untracked directories inside it, so a plain status would call
  # every space dirty forever. Under -uall an ordinary untracked directory expands to its files
  # while a nested git repo stays a single `?? path/` entry — drop those, since the walk in
  # _wsm_unpushed assesses each nested repo on its own.
  if [[ -n "$(git -C "$repo" status --porcelain -uall 2>/dev/null | grep -v '^?? .*/$')" ]]; then
    why="uncommitted or untracked changes"
  elif ! git -C "$repo" remote | grep -q .; then
    why="no remote to push to"
  elif [[ -n "$(git -C "$repo" log --branches --not --remotes --oneline 2>/dev/null)" ]]; then
    why="commits that are not on any remote"
  fi

  [[ -n "$why" ]] && printf '  %s: %s\n' "${repo/#$HOME/~}" "$why"
  return 0
}
