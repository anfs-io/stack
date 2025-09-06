#!/usr/bin/env bash
set -e

# TODO: Add a second stow to loop on which has packages without the leading .config
# and have the dest be ansbile_user_dir/.config
# TODO: Fix the packages failing b/c stow doesn't own the dir


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
  stow -d $REPO_DIR -t $HOME scripts
}

setup() {
  local user=$(whoami)
  sudo usermod -s /bin/zsh $user
  sudo apt install git stow -y
  git clone git@github.com:maxcole/rjayroach-home.git $REPO_DIR
  $REPO_DIR/$SCRIPT_NAME dotfiles scripts
}

if [ $# -eq 0 ]; then
  echo "Usage: $0 [params]"
  echo "  setup: Install git and stow, clone this repo and stow dotfiles and scripts"
  echo "  dotfiles: Stow the dotfiles"
  echo "  scripts: Stow the scripts"
else
  for function_to_call in "$@"; do
    $function_to_call
  done
fi
