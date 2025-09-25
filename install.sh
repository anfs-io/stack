#!/usr/bin/env bash
set -euo pipefail

#######
# The 'coder' package manager, aka 'cpm'
#
# Two profiles
# 1. remote - export shares, full env, ssh auth key(s); typically linux hosts
# 2. local - mount shares, partial env, ssh private key(s); typically mac hosts
#
# Process for all profiles:
# 1. Install deps (based on os + arch)
# 2. Clone the repos
# 3. Install packages (with functions appropriate on os + arch + profile)
# 3a. zsh basics
# 3b. ssh stuff
#######

CONFIG_DIR=$HOME/.config
BIN_DIR=$HOME/.local/bin
PROJECTS_DIR=$HOME/code/projects

LIB_FILE=$PROJECTS_DIR/pcs/bootstrap/library.sh
LIB_URL=https://raw.githubusercontent.com/maxcole/pcs-bootstrap/refs/heads/main/library.sh

CODE_DIR=$PROJECTS_DIR/rjayroach
CODE_REPO_PREFIX="git@github.com:maxcole/rjayroach"
CODE_REPOS=("claude" "coder")

CODER_PROFILES=("local" "remote")
CODER_PROFILE_DIR=$CONFIG_DIR/zsh
CODER_PROFILE_FILE=$CODER_PROFILE_DIR/coder_profile.zsh

# Source a local copy of the library file or download from a URL
if [ ! -f $LIB_FILE ]; then
  lib_dir=$HOME/.cache/coder
  mkdir -p $lib_dir
  LIB_FILE=/$lib_dir/library.sh
  if [ ! -f $LIB_FILE ]; then # Download and source the script
    if command -v wget &> /dev/null; then
      wget -O $LIB_FILE $LIB_URL
    elif command -v curl &> /dev/null; then
      curl -o $LIB_FILE $LIB_URL
    else
      echo "install wget or curl to continue."
      exit 1
    fi
  fi
fi
source $LIB_FILE

# Run Once to set the shell, install deps, clone the repo and run the functions
install_deps() {
  if [ ! check_sudo ]; then
    echo "no sudo"
    return
  fi
  # TODO: if not has_sudo_all
  local deps=("curl" "git" "stow" "wget")
  local missing_deps=()

  for dep in "${deps[@]}"; do
    if ! command -v $dep &> /dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if [ ${#missing_deps[@]} -ne 0 ]; then
    if [[ "$(os)" == "linux" ]]; then
      sudo apt install -y ${missing_deps[*]}
    elif [[ "$(os)" == "macos" ]]; then
      deps_macos
      brew install ${missing_deps[*]}
    fi
  fi
}

clone_repos() {
  if has_ssh_access; then
    for repo in "${CODE_REPOS[@]}"; do
      if [ ! -d $CODE_DIR/$repo ]; then
        git clone "$CODE_REPO_PREFIX-$repo.git" $CODE_DIR/$repo
      fi
    done
  fi
}

prompt_profile() {
  if [[ -z "${CODER_PROFILE:-}" ]]; then
    if [ -f $CODER_PROFILE_FILE ]; then
      source $CODER_PROFILE_FILE
    else
      while true; do
        read -p "Coder profile [${CODER_PROFILES[*]}]: " CODER_PROFILE
        if [[ " ${CODER_PROFILES[*]} " =~ " $CODER_PROFILE " ]]; then
          break
        fi
      done
      mkdir -p $CODER_PROFILE_DIR
      echo "export CODER_PROFILE=$CODER_PROFILE" > $CODER_PROFILE_FILE
    fi
  fi
}

# this script takes parameters of packages to install
# so ./install.sh ruby tmux zsh neovim
# and if it is just ./install then it is the base package by default
# Each package can call this function to install their deps
install_packages() {
  requested_packages=("$@")
  for pkg in "${requested_packages[@]}"; do
    pkg_dir=$CODE_DIR/coder/packages/$pkg

    if [[ ! -d $pkg_dir ]]; then
      echo "Invalid package: $pkg"
    fi

    # for each package passed in check if there is a package install.sh and run it if it is there
    if [[ -f $pkg_dir/install.sh ]]; then
      source $pkg_dir/install.sh
      if [[ "$(os)" == "linux" ]]; then
        install_linux
      elif [[ "$(os)" == "macos" ]]; then
        install_macos
      fi
    fi

    if [[ -d $pkg_dir/home ]]; then
      stow -d $pkg_dir -t $HOME home
    fi
  done
}

prompt_profile
debug
setup_xdg
install_deps
clone_repos
mkdir -p $CONFIG_DIR/zsh
if [[ $# -gt 0 ]]; then
  install_packages $@
else
  # all_packages=$(find packages -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n')
  all_packages=("bash")
  install_packages $all_packages
fi


# AUTHORIZED_KEYS_URL="https://github.com/rjayroach.keys"
# ssh_random() {
#   local user=$(whoami)
#   local home_dir
#   home_dir=$(userhome)
#   curl -o "$home_dir/.ssh/authorized_keys" "$AUTHORIZED_KEYS_URL"
#   setup_xdg
# }
