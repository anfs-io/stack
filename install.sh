#!/usr/bin/env bash
set -e

# TODO: Add a second stow to loop on which has packages without the leading .config with dest $HOME/.config

REPO_URL="git@github.com:maxcole/rjayroach-home.git"
REPO_DIR=$HOME/rjayroach/home
SCRIPT_NAME=`basename "$0"`

# Detect the CPU architecture
detect_arch() {
  local arch=$(uname -m)

  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    echo "arm64"
  else
    echo "amd64"
  fi
}

# Detect the OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  else
    echo "unsupported"
  fi
}

setup_xdg() {
  mkdir -p $HOME/.cache $HOME/.config $HOME/.local $HOME/.local/share $HOME/.local/state $HOME/.local/bin
}


# Dependencies
deps_linux() {
  sudo install -dm 755 /etc/apt/keyrings
  wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg 1> /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(detect_arch)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
  sudo apt update

  # general
  sudo apt install git neovim stow -y

  # mise
  sudo apt install curl gpg mise -y

  # tmux
  sudo apt install entr tmux -y
  if [ ! -d $HOME/.local/share/tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm $HOME/.local/share/tmux/plugins/tpm
  fi

  # zsh
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

deps_macos() {
  if ! command -v python3 >/dev/null 2>&1; then
    debug "ERROR!!"
    debug ""
    debug "python interpreter not found. Run 'xcode-select --install' from a terminal then rerun this script"
    exit 1
  fi
}

# Run Once to set the shell, install deps, clone the repo and run the functions
deps() {
  local user=$(whoami)

  if [[ "$(detect_os)" == "linux" ]]; then
    deps_linux
  elif [[ "$(detect_os)" == "macos" ]]; then
    deps_macos
  fi

  if [[ ! -d "$REPO_DIR" ]]; then
    git clone $REPO_URL $REPO_DIR
  fi

  setup_xdg
}

configure() {
  nvim --headless "+Lazy! sync" +qa
  tmux -c $HOME/.local/share/tmux/plugins/tpm/bin/install_plugins
  tmux -c $HOME/.local/share/tmux/plugins/tpm/tpm
}

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

# Parse command line arguments
functions_to_call=()

if [ $# -eq 1 -a "$1" = "all" ]; then
  functions_to_call+=("deps" "dotfiles" "scripts")
elif [ $# -gt 0 ]; then
  functions_to_call=("$@")
else
  echo "Usage: $0 [params]"
  echo "  all: Execute all of the below commands"
  echo ""
  echo "  deps: Set the shell, install deps, clone this repo and stow dotfiles and scripts"
  echo "  dotfiles: Stow the dotfiles"
  echo "  scripts: Stow the scripts"
fi

for function_to_call in "${functions_to_call[@]}"; do
  $function_to_call
done
