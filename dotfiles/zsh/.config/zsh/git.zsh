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

git-repos() {
  local search_dir="${1:-$PROJECTS_DIR}"
  local current_dir=$PWD

  find "$search_dir" -maxdepth 3 -name ".git" -type d | while read gitdir; do
    local repo_path=$(dirname "$gitdir")
    local xstatus=""

    cd "$repo_path"
    if ! git diff-index --quiet HEAD 2>/dev/null || [[ -n $(git ls-files --others --exclude-standard) ]]; then
      xstatus=" - has-modifications"
    fi

    echo "$repo_path$xstatus"
  done
  cd $current_dir
}

git-status() {
  git fetch
  git status
}

max-clone() {
  git clone $PROJECTS_GIT_REMOTE_PREFIX/$1.git
}
