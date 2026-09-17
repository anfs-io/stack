# zsh

post_install() {
  local omz_dir=$XDG_DATA_HOME/omz
  if [ ! -d "$omz_dir" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git $omz_dir
  fi
  if [ ! -d $omz_dir/custom/plugins/zsh-history-substring-search ]; then
    git clone https://github.com/zsh-users/zsh-history-substring-search.git $omz_dir/custom/plugins/zsh-history-substring-search
  fi
  if [ ! -d $omz_dir/custom/themes/powerlevel10k ]; then
    git clone https://github.com/romkatv/powerlevel10k.git $omz_dir/custom/themes/powerlevel10k
  fi
  mkdir -p $omz_dir/custom/functions

  _zsh_login_shell
}

# Make zsh the login shell if it isn't already. chsh changes the current user's own shell, so no
# sudo is needed; a rerun does nothing.
# stdin is closed on purpose: chsh asks for the user's password through PAM and would block
# forever in a non-interactive install. Without stdin it fails immediately and we print the
# command to run by hand.
_zsh_login_shell() {
  local zsh_path user current
  zsh_path=$(command -v zsh) || return 0
  user=$(id -un)

  if [[ "$(os)" == "macos" ]]; then
    current=$(dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{print $2}')
  else
    current=$(getent passwd "$user" | cut -d: -f7)
  fi

  # Compare resolved paths: /bin/zsh and /usr/bin/zsh are the same file on Debian
  local current_real zsh_real
  current_real=$(readlink -f "$current" 2>/dev/null || echo "$current")
  zsh_real=$(readlink -f "$zsh_path" 2>/dev/null || echo "$zsh_path")
  [[ "$current_real" == "$zsh_real" ]] && return 0

  if chsh -s "$zsh_path" </dev/null >/dev/null 2>&1; then
    user_message "Login shell set to $zsh_path; it takes effect on your next login"
  else
    user_message "Login shell unchanged (chsh needs your password). Run: chsh -s $zsh_path"
  fi
}

post_remove() {
  rm -rf $XDG_DATA_HOME/omz $XDG_CACHE_HOME/p10k-*
}
