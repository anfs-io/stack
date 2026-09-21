# ~/.bashrc — bash config assembled from package-contributed snippets (pde/bash)
#
# Two tiers, sourced in this order:
#   ~/.config/sh/*.sh        portable, shared with zsh
#   ~/.config/bash/*.bash    bash-specific
# A portable file must not rely on a helper defined in a bash-specific one at source time;
# calling one at runtime is fine (that is how ppm's _ppm_shell_reload hook works).

case $- in *i*) ;; *) return ;; esac   # interactive shells only

# XDG and ppm directories, matching pde/zsh's aliases.zsh
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export BIN_DIR=$HOME/.local/bin
export LIB_DIR=$HOME/.local/lib

# Homebrew on PATH, wherever it is installed, before $BIN_DIR is prepended so ~/.local/bin
# stays first. The base env lives here rather than in a ~/.config/bash/*.bash snippet because
# the snippet loop below needs ppm and mise to already be findable, and because shipping
# ~/.bash_profile stops bash login shells from reading the distro's ~/.profile (which is what
# puts ~/.local/bin on PATH on Debian).
if [ -z "${HOMEBREW_PREFIX:-}" ]; then
  for _brew_prefix in /opt/homebrew /home/linuxbrew/.linuxbrew; do
    if [ -x "$_brew_prefix/bin/brew" ]; then
      eval "$("$_brew_prefix/bin/brew" shellenv bash)"
      break
    fi
  done
  unset _brew_prefix
fi

# Put $BIN_DIR first, removing any existing occurrence so repeated sourcing can't duplicate it
_ppm_clean_path=":$PATH:"
_ppm_clean_path="${_ppm_clean_path//:$BIN_DIR:/:}"
_ppm_clean_path="${_ppm_clean_path#:}"
_ppm_clean_path="${_ppm_clean_path%:}"
export PATH="$BIN_DIR${_ppm_clean_path:+:$_ppm_clean_path}"
unset _ppm_clean_path

# Two levels of nesting are globbed explicitly rather than with `shopt -s globstar`: macOS
# ships bash 3.2, which has no globstar. Two levels is what packages actually use
# (~/.config/zsh/op/, ssh/, ruby/).
_ppm_nullglob=$(shopt -p nullglob)
shopt -s nullglob
for _ppm_file in "$HOME"/.config/sh/*.sh "$HOME"/.config/sh/*/*.sh \
                 "$HOME"/.config/bash/*.bash "$HOME"/.config/bash/*/*.bash; do
  . "$_ppm_file"
done
eval "$_ppm_nullglob"
unset _ppm_nullglob _ppm_file
