# Git

alias gmv="git mv"
alias gpl="git pull"

alias git-repos="find ~ -maxdepth 5 -path ~/.local -prune -o -type d -execdir test -d {}/.git \; -print -prune | sort"

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

git-clone() {
  local repo_dir=$HOME/$(echo "$1" | sed 's/[-\.]/\//g')
  if [ ! -d $repo_dir ]; then
    git clone git@github.com:maxcole/$1.git $repo_dir
  fi
  echo $repo_dir
}
