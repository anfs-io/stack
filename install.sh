#!/usr/bin/env bash
set -e

# TODO: Add a second stow to loop on which has packages without the leading .config with dest $HOME/.config

CODE_URL="git@github.com:maxcole/claude.git"
CODE_DIR=$HOME/code

REPO_URL="git@github.com:maxcole/rjayroach-home.git"
REPO_DIR=$CODE_DIR/projects/rjayroach/home

SCRIPT_DIR=$(dirname "$0")
SCRIPT_NAME=$(basename "$0")

# Download and source the script
if [ ! -f /tmp/pcs-library.sh ]; then
  wget -O /tmp/pcs-library.sh https://raw.githubusercontent.com/maxcole/pcs-bootstrap/refs/heads/main/library.sh
fi
source /tmp/pcs-library.sh

# Dependencies
deps_linux() {
  # general
  sudo apt install bat git neovim stow tree -y

  # ruby
  sudo apt install build-essential zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
    libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev git -y

  # tmux
  sudo apt install entr tmux -y
  if [ ! -d $HOME/.local/share/tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm $HOME/.local/share/tmux/plugins/tpm
  fi

  mise_linux
  # eval "$(mise activate zsh)" && mise install
  mise install

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

  if [[ "$(os)" == "linux" ]]; then
    deps_linux
  elif [[ "$(os)" == "macos" ]]; then
    deps_macos
  fi

  if [[ ! -d "$CODE_DIR" ]]; then
    git clone $CODE_URL $CODE_DIR
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
  dirs=("git" "mise/conf.d" "nvim" "pry" "rails" "ruby" "tmux" "tmuxinator" "zsh")
  for dir in "${dirs[@]}"; do
    mkdir -p $HOME/.config/$dir
  done

  # Stow the packages found in ./dotfiles to ~
  packages=("bash" "claude" "git" "mise" "nvim" "pry" "rails" "ruby" "tmux" "tmuxinator" "zsh")
  for pkg in "${packages[@]}"; do
    stow -d $SCRIPT_DIR/dotfiles -t $HOME $pkg
  done
}

scripts() {
  mkdir -p $HOME/.local/bin
  stow -d $SCRIPT_DIR -t $HOME scripts
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
