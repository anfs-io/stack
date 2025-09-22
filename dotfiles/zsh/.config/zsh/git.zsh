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
