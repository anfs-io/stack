# Git

alias gmv="git mv"
alias gpl="git pull"

# git add, commit, push
gacp() {
  local message=""
  if (( $# == 1 )); then
    message=$1
  else
    vared -p "Git commit message: " message
  fi
  git add .
  git commit -m "${message}"
  git push
}

git-status() {
  git fetch
  git status
}

git-reorg() {
  local dry_run=false
  if [[ "$1" == "-n" || "$1" == "--dry-run" ]]; then
    dry_run=true
    shift
  fi

  local new_org=$1
  if [[ -z "$new_org" ]]; then
    echo "Usage: gh-reorg [-n|--dry-run] <new-org>"
    return 1
  fi

  local origin=$(git remote get-url origin)
  local repo=$(basename "$origin")

  if [[ "$origin" == git@* ]]; then
    local new_url="git@github.com:${new_org}/${repo}"
  else
    local new_url="https://github.com/${new_org}/${repo}"
  fi

  if $dry_run; then
    echo "Would update origin from $origin to $new_url"
  else
    git remote set-url origin "$new_url"
    # git branch --set-upstream-to=origin/main main
    echo "Updated origin to $new_url"
  fi
}

gh-create-repos() {
  local org=$1
  local name=$2

  if [[ -z "$org" || -z "$name" ]]; then
    echo "Usage: gh-create-repos <org> <name>"
    return 1
  fi

  gh repo create "${org}/${name}-space" --private
  gh repo create "${org}/${name}-ppm" --private
}
