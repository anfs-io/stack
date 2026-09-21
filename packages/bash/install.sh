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

# Put back the most recent backup if this package's link is gone, so removing pde/bash leaves a
# working shell on a machine whose distro rc we moved aside.
post_remove() {
  local f
  for f in .bashrc .bash_profile .bash_login; do
    [[ -e "$HOME/$f.pre-ppm" && ! -e "$HOME/$f" ]] || continue
    mv "$HOME/$f.pre-ppm" "$HOME/$f"
    user_message "Restored your original $f"
  done
}
