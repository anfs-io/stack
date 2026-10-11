# bash

# bash's rc paths are fixed, so a distro's own ~/.bashrc (Debian and Fedora both ship one) sits
# exactly where this package stows. Move it aside instead of letting stow abort the install or
# `-f` delete it: the user keeps the file and can copy anything they want into their own repo.
# ~/.profile is left alone, but note that shipping ~/.bash_profile stops bash login shells from
# reading it — .bashrc sets the base env (PATH, brew, XDG) itself for that reason.
pre_install() {
  local f saved moved=""
  for f in .bashrc .bash_profile .bash_login; do
    [[ -e "$HOME/$f" && ! -L "$HOME/$f" ]] || continue
    saved="$HOME/$f.pre-ppm"
    # Never clobber an earlier backup
    local n=1
    while [[ -e "$saved" ]]; do
      saved="$HOME/$f.pre-ppm.$n"
      n=$((n + 1))
    done
    mv "$HOME/$f" "$saved"
    moved="${moved:+$moved, }$f -> $(basename "$saved")"
  done
  [[ -z "$moved" ]] || user_message "Moved your existing bash config aside: $moved"
}

# macOS only: installing this package means "I want bash", and on macOS the bash you want is
# brew's 5.x — /bin/bash is 3.2.57 and Apple will never move off it (GPLv3). On Linux the distro
# bash is already 5.2+ and stays the login shell: brew's Linux prefix is under /home, which may
# not be mounted when login runs (autofs, NFS); SELinux labels binaries there user_home_t rather
# than shell_exec_t; and brew may link its own glibc. pde/zsh's package.yml makes the same call
# for the same reason, taking zsh from the distro so the login shell is a path in /etc/shells.
post_install() {
  [[ "$(os)" == "macos" ]] || return 0
  _bash_login_shell
}

# Register brew's bash in /etc/shells (chpass rejects anything not listed there, and Homebrew
# stopped printing a caveat about it) and make it the login shell. Both steps are no-ops once
# done, so a rerun costs one grep and one dscl read and never prompts. Reruns matter: a macOS
# update rewrites /etc/shells, and this is what puts the entry back.
#
# The path is $(brew_prefix)/bin/bash, never `command -v bash`: hooks run under whatever bash won
# the PATH race, which in a nested login shell may be /bin/bash itself, so resolving through PATH
# could register the very 3.2 we are escaping and still look like a success. It is also the
# stable path — brew repoints that symlink on every upgrade, so a resolved Cellar path would
# break login the next time bash is bumped.
_bash_login_shell() {
  local prefix bash_path user current current_real bash_real
  prefix=$(brew_prefix)
  [[ -n "$prefix" ]] || return 0
  bash_path="$prefix/bin/bash"
  [[ -x "$bash_path" ]] || return 0

  # /etc/shells is root-owned, the one step here that needs sudo. grep first so the settled case
  # never prompts; -n on the write because _system_sudo has just primed the credential cache, so
  # it cannot block an unattended install (tee reads the pipe, never a terminal).
  if ! grep -qxF "$bash_path" /etc/shells 2>/dev/null; then
    if _system_sudo "$bash_path" \
        "Adding $bash_path to /etc/shells needs sudo; run: echo $bash_path | sudo tee -a /etc/shells"
    then
      printf '%s\n' "$bash_path" | sudo -n tee -a /etc/shells >/dev/null || return 0
    else
      user_message "bash is not your login shell yet. Run:\necho $bash_path | sudo tee -a /etc/shells\nchsh -s $bash_path"
      return 0
    fi
  fi

  user=$(id -un)
  # `|| current=""` because ppm runs under set -o pipefail: a dscl failure would otherwise abort
  # the install subshell instead of falling through to the chsh attempt
  current=$(dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{print $2}') || current=""

  # Compare resolved paths, so a Cellar path someone set by hand counts as already set
  current_real=$(readlink -f "$current" 2>/dev/null || echo "$current")
  bash_real=$(readlink -f "$bash_path" 2>/dev/null || echo "$bash_path")
  [[ "$current_real" == "$bash_real" ]] && return 0

  # stdin is closed on purpose: chsh asks for the user's password through PAM and would block
  # forever in a non-interactive install. Without a terminal it fails immediately, so fall back
  # to sudo chsh <user> — root changes another account's shell without a password, and the sudo
  # cache is already warm from the /etc/shells step. If that is gone too, print the command.
  if chsh -s "$bash_path" </dev/null >/dev/null 2>&1 ||
     { sudo -n true 2>/dev/null && sudo -n chsh -s "$bash_path" "$user" >/dev/null 2>&1; }; then
    user_message "Login shell set to $bash_path; it takes effect on your next login"
    # Not a prefix write, so brew ownership does not gate this (chsh touches your own account
    # record, tee touches a root-owned file). But a non-owner cannot reinstall the formula, so
    # say who can take it away. This is an availability note, not a permission problem.
    brew_is_owner ||
      user_message "$bash_path belongs to Homebrew owner $(brew_owner); if they uninstall the bash formula your login shell goes with it"
  else
    user_message "Login shell unchanged (chsh needs your password). Run: chsh -s $bash_path"
  fi
}

# Put back the most recent backup if this package's link is gone, so removing pde/bash leaves a
# working shell on a machine whose distro rc we moved aside.
#
# The login shell is deliberately left as it is. ppm remove does not uninstall brew's bash
# (package.yml declares no brew: [bash] — install.sh owns it as an untracked bootstrap formula),
# so the shell keeps working and there is nothing to rescue; changing someone's login shell
# during a remove would be a bigger surprise than leaving it. The /etc/shells line stays for the
# same reason plus two more: it is machine-wide, and it is still accurate. Just say what to run.
post_remove() {
  local f
  for f in .bashrc .bash_profile .bash_login; do
    [[ -e "$HOME/$f.pre-ppm" && ! -e "$HOME/$f" ]] || continue
    mv "$HOME/$f.pre-ppm" "$HOME/$f"
    user_message "Restored your original $f"
  done

  [[ "$(os)" == "macos" ]] || return 0
  local prefix current
  prefix=$(brew_prefix)
  [[ -n "$prefix" ]] || return 0
  current=$(dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}') || current=""
  [[ "$current" == "$prefix/bin/bash" ]] || return 0
  user_message "Your login shell is still $current. Removing this package does not uninstall it, so it keeps working.\nTo switch back: chsh -s /bin/zsh"
}
