#!/usr/bin/env bash

if [[ "$1" == "install" ]]; then
  sudo apt install stow -y
  mkdir $HOME/rjayroach
  git clone git@github.com:maxcole/rjayroach-config.git $HOME/rjayroach/config
  $HOME/rjayroach/config/bootstrap.sh setup
  exit 0
fi


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

dirs=("git" "nvim" "tmuxinator")
for dir in "${dirs[@]}"; do
  mkdir -p $HOME/.config/$dir
done

    # TODO: Add a second stow to loop on which has packages without the leading .config
    # and have the dest be ansbile_user_dir/.config
    # TODO: Fix the packages failing b/c stow doesn't own the dir

# packages: [bash, git, nvim, tmux, tmuxinator, zsh]
packages=("bash" "git") #  "zsh")

for pkg in "${packages[@]}"; do
  stow -d $SCRIPT_DIR/dotfiles -t $HOME $pkg
done

