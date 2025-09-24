#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR=$HOME/.config
BIN_DIR=$HOME/.local/bin
PROJECTS_DIR=$HOME/code/projects
LIB_FILE=$PROJECTS_DIR/pcs/bootstrap/library.sh

CODE_DIR=$PROJECTS_DIR/rjayroach
CODE_REPO_PREFIX="git@github.com:maxcole/rjayroach"
CODE_REPOS=("claude" "home")

AUTHORIZED_KEYS_URL="https://github.com/rjayroach.keys"
BASE_PACKAGES=("bash" "mise" "zsh")

# Source a local copy of the library file or download from a URL
if [ ! -f $LIB_FILE ]; then
  LIB_FILE=/tmp/pcs-library.sh
  if [ ! -f $LIB_FILE ]; then # Download and source the script
    wget -O $LIB_FILE https://raw.githubusercontent.com/maxcole/pcs-bootstrap/refs/heads/main/library.sh
  fi
fi
source $LIB_FILE

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

# CODE_URL="git@github.com:maxcole/claude.git"
# 
# REPO_URL="git@github.com:maxcole/rjayroach-home.git"
# REPO_DIR=$CODE_DIR/projects/rjayroach/home

# SCRIPT_DIR=$(dirname "$0")
# SCRIPT_NAME=$(basename "$0")

# STOW_DIRS=("git" "mise/conf.d" "nvim" "ruby" "tmux" "tmuxinator" "zsh")
# STOW_PACKAGES=("bash" "git" "mise" "nvim" "ruby" "tmux" "tmuxinator" "ventoy" "zsh")

# Run Once to set the shell, install deps, clone the repo and run the functions
install_deps() {
  # TODO: if has_sudo_all
  if [[ "$(os)" == "linux" ]]; then
    sudo apt install git stow -y
  elif [[ "$(os)" == "macos" ]]; then
    deps_macos
    # brew install stow (git should already be available)
  fi
}

clone_repos() {
  if has_ssh_access; then
    for repo in "${CODE_REPOS[@]}"; do
      git clone "$CODE_REPO_PREFIX-$repo.git" $CODE_DIR/$repo
    done
  fi
}

install_packages() {
  # TODO: the mkdir is handled by the package installer
  # mkdir -p $CONFIG_DIR/mise/conf.d $CONFIG_DIR/zsh
  # TODO: source the install script from each package in $CODE_DIR/home/dotfiles / $BASE_PACKAGES (bash, mise, zsh)
  source $CODE_DIR/home/packages/bash/install.sh #  / $BASE_PACKAGES (bash, mise, zsh)
  # TODO: maybe the bash stuff should jsut be combined with zsh

#   for pkg in "${STOW_PACKAGES[@]}"; do
# STOW_PACKAGES=("bash" "git" "mise" "nvim" "ruby" "tmux" "tmuxinator" "ventoy" "zsh")
#     stow -d $REPO_DIR/dotfiles -t $HOME $pkg
}

setup_xdg
install_deps
clone_repos
install_packages



# -----------
deps_linux_other() {
  sudo apt install bat tree -y

  # ruby
  sudo apt install build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
    libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev git -y

  # tmux
  sudo apt install entr tmux -y
  if [ ! -d $HOME/.local/share/tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm $HOME/.local/share/tmux/plugins/tpm
  fi

  deps_mise
  deps_zsh
  deps_github_cli
  deps_neovim
}


deps_zsh() {
  sudo apt install fzf zsh -y
  sudo usermod -s /bin/zsh $user

  local omz_dir=$HOME/.local/share/omz
  if [ ! -d "$omz_dir" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git $omz_dir
  fi
  if [ ! -d $omz_dir/custom/plugins/zsh-history-substring-search ]; then
    git clone https://github.com/zsh-users/zsh-history-substring-search.git $omz_dir/custom/plugins/zsh-history-substring-search
  fi
  if [ ! -d $omz_dir/custom/themes/powerlevel10k ]; then
    git clone https://github.com/romkatv/powerlevel10k.git $omz_dir/custom/themes/powerlevel10k
  fi
}


deps_github_cli() {
  if command -v gh &>/dev/null; then
    return
  fi

  # TODO: If command -v gh then return
  (type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
}


deps_neovim() {
  local install_path="${HOME}/.local/bin/nvim"

  if [ -f $install_path ]; then
    return
  fi

  # Check for FUSE (required for AppImages)
  if ! ldconfig -p | grep -q libfuse.so.2; then
    echo "FUSE2 is not installed. Installing libfuse2..."
    sudo apt-get install libfuse2 fuse3 -y
  fi

  # nvim release arch
  local nvim_arch="x86_64"
  if [[ "$(arch)" == "arm64" ]]; then
    nvim_arch="arm64"
  fi

  # Neovim version - using 'stable' to always get the latest stable release
  local nvim_version="stable"
  local download_url="https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim-linux-${nvim_arch}.appimage"

  # Create ~/.local/bin if it doesn't exist
  mkdir -p $HOME/.local/bin
  curl -L -o "$install_path" "$download_url"
  chmod +x "$install_path" # Make it executable
  echo "Neovim (${nvim_version}) installed successfully to ${install_path}"
  "$install_path" --version | head -n 1 # Test the installation
}


links() {
  if [[ ! -d "$REPO_DIR" ]]; then
    return
  fi

  # Create dirs in ~/.config so stow does NOT softlink the entire directory to this repo
  for dir in "${STOW_DIRS[@]}"; do
    mkdir -p $HOME/.config/$dir
  done

  # Stow the packages found in ./dotfiles to ~
  for pkg in "${STOW_PACKAGES[@]}"; do
    stow -d $REPO_DIR/dotfiles -t $HOME $pkg
  done

  mkdir -p $HOME/.local/bin
  stow -d $REPO_DIR -t $HOME scripts
}


configure() {
  if [[ ! -d "$REPO_DIR" ]]; then
    return
  fi

  # Use the absolute path b/c PATH is not yet configured
  $HOME/.local/bin/nvim --headless "+Lazy! sync" +qa
  tmux -c $HOME/.local/share/tmux/plugins/tpm/bin/install_plugins
  tmux -c $HOME/.local/share/tmux/plugins/tpm/tpm

  eval "$(mise activate zsh)" && mise install
  # mise install
}


ssh_random() {
  local user=$(whoami)
  local home_dir
  home_dir=$(userhome)
  curl -o "$home_dir/.ssh/authorized_keys" "$AUTHORIZED_KEYS_URL"
  setup_xdg
}

# Parse command line arguments
functions_to_call=()

if [ $# -eq 1 -a "$1" = "all" ]; then
  functions_to_call+=("deps" "repos" "links" "configure")
elif [ $# -gt 0 ]; then
  functions_to_call=("$@")
else
  echo "Usage: $0 [params]"
  echo "  all: Execute all of the below commands"
  echo ""
  echo "  deps: Set the shell, install deps, clone this repo and stow dotfiles and scripts"
  echo "  repos: Clone the rpositories"
  echo "  links: Stow the dotfiles and scripts"
  echo "  configure: Configure installation"
fi

for function_to_call in "${functions_to_call[@]}"; do
  # $function_to_call
done
