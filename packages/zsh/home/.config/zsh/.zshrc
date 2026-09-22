# BEGIN ENABLE P10K
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# export FZF_BASE=$HOME/.local/bin
# source <(fzf --zsh)
# END ENABLE P10K
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.local/share/omz"
export ZSH_CONFIG="$HOME/.config/zsh"
# Portable snippets shared with bash (see the shell-integration tiers in ppm's CLAUDE.md)
export SH_CONFIG="$HOME/.config/sh"

# XDG directories
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state

# non XDG directories
export BIN_DIR=$HOME/.local/bin
export LIB_DIR=$HOME/.local/lib

# The base environment lives here, not in a snippet, because the snippet loop at the bottom
# sources the portable ~/.config/sh/*.sh tier first and those files guard on `command -v <tool>`:
# PATH must already be complete when the first snippet loads. pde/bash's .bashrc does the same.

# Put $target first on PATH, removing any existing occurrence so repeats can't duplicate it.
# Packages call this from their own .zsh files (pde/ruby-tools, pdt/solana), and pde/bash's
# .bashrc defines the same helper, so a portable ~/.config/sh/*.sh snippet can call it in either
# shell. Defined before the Homebrew block because that block calls it too.
ensure_path() {
  local target="$1"
  # Strip target from start, middle, and end of PATH
  local clean_path=":$PATH:"
  clean_path="${clean_path//:$target:/:}"
  clean_path="${clean_path#:}"
  clean_path="${clean_path%:}"

  export PATH="$target${clean_path:+:$clean_path}"
}

# Find Homebrew, wherever it is installed. `brew shellenv` forks, and everything it exports but
# PATH survives being inherited ($HOMEBREW_*, FPATH, INFOPATH), so it stays behind this guard
# and runs once per session rather than once per nested shell.
if [[ -z $HOMEBREW_PREFIX ]]; then
  for _brew_prefix in /opt/homebrew /home/linuxbrew/.linuxbrew; do
    if [[ -x $_brew_prefix/bin/brew ]]; then
      eval "$($_brew_prefix/bin/brew shellenv zsh)"
      break
    fi
  done
  unset _brew_prefix
fi

# PATH is the one thing shellenv sets that does NOT survive, so re-assert it on every run, guard
# or no guard: macOS runs /usr/libexec/path_helper from /etc/zprofile in EVERY login shell,
# including nested ones (tmux starts one by default, as do `zsh -l`, ssh to self, and an editor's
# or agent's shell), and it rebuilds PATH with the /etc/paths entries in front. A nested login
# shell inherits $HOMEBREW_PREFIX, so the guard above skips shellenv and path_helper's demotion
# would stand: /opt/homebrew/bin below /bin, i.e. `bash` resolving to Apple's 3.2.57 instead of
# brew's 5.x. sbin is prepended first so bin lands ahead of it, the order `brew shellenv`
# produces, and $BIN_DIR goes on last so ~/.local/bin stays first overall.
if [[ -n $HOMEBREW_PREFIX ]]; then
  [[ -d $HOMEBREW_PREFIX/sbin ]] && ensure_path "$HOMEBREW_PREFIX/sbin"
  [[ -d $HOMEBREW_PREFIX/bin ]] && ensure_path "$HOMEBREW_PREFIX/bin"
fi

ensure_path "$BIN_DIR"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(ansible aws debian docker docker-compose gem git helm kubectl nmap python rails ruby ssh tmuxinator)
# zsh-history-substring-search)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#
# echo $PATH | tr ':' '\n' > ~/path.txt
# Portable tier first, then the zsh-specific one: a $SH_CONFIG file must not rely on a helper
# defined under $ZSH_CONFIG at source time (calling one at runtime is fine).
setopt extended_glob
for file in $SH_CONFIG/**/*.sh(N) $ZSH_CONFIG/**/*.zsh(N); do
  source "$file"
done
# echo "\n\n" >> ~/path.txt
# echo $PATH | tr ':' '\n' >> ~/path.txt
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
