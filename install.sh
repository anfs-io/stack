#!/usr/bin/env bash
set -e

# TODO: Add a second stow to loop on which has packages without the leading .config with dest $HOME/.config

REPO_URL="git@github.com:maxcole/rjayroach-home.git"
REPO_DIR=$HOME/rjayroach/home
SCRIPT_NAME=`basename "$0"`

# Create dirs in ~/.config so stow does NOT softlink the entire directory to this repo
dotfiles() {
  dirs=("git" "nvim" "tmuxinator" "zsh")
  for dir in "${dirs[@]}"; do
    mkdir -p $HOME/.config/$dir
  done

  # Stow the packages found in ./dotfiles to ~
  packages=("bash" "git" "nvim" "tmux" "tmuxinator" "zsh")
  for pkg in "${packages[@]}"; do
    stow -d $REPO_DIR/dotfiles -t $HOME $pkg
  done
}

scripts() {
  mkdir -p $HOME/.local/bin
  stow -d $REPO_DIR -t $HOME scripts
}

# Run Once to set the shell, install deps, clone the repo and run the functions
setup() {
  local user=$(whoami)
  sudo usermod -s /bin/zsh $user
  sudo apt install git stow -y
  git clone $REPO_URL $REPO_DIR
}

# Parse command line arguments
functions_to_call=()

if [ $# -eq 1 -a "$1" = "all" ]; then
  functions_to_call+=("setup" "dotfiles" "scripts")
elif [ $# -gt 0 ]; then
  functions_to_call=("$@")
else
  echo "Usage: $0 [params]"
  echo "  all: Execute all of the below commands"
  echo ""
  echo "  setup: Set the shell, install deps, clone this repo and stow dotfiles and scripts"
  echo "  dotfiles: Stow the dotfiles"
  echo "  scripts: Stow the scripts"
fi

for function_to_call in "${functions_to_call[@]}"; do
  $function_to_call
done
