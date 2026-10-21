# stack/obsidian
#
# Installs ovm (~/.local/bin/ovm), the Obsidian Vault Manager: documentation vaults (Obsidian or
# plain markdown) whose directories are linked into wsm spaces, and whose documents are found by
# a stable id. The nvim plugin config and the `ob` alias are stowed with it.
#
# ovm listens to wsm (lib/anfs/callbacks.sh): when wsm installs a level, ovm creates the links
# that point into it; when wsm removes one, ovm removes them. wsm knows nothing about ovm. The
# registration is kept by anfs, so it outlives a wsm implode and goes when ovm is removed.
#
# ovm was pvm, a core tool, until 2026-10-21. post_install carries a pvm install over once: the
# state directory moves to ovm's, and each registered vault's pvm.yml becomes ovm.yml.

post_install() {
  anfs_callback_register wsm "$PPM_CURRENT_PACKAGE" "ovm link apply --event"
  _ovm_migrate
  user_message "Make a directory of documents a vault: ovm init <dir>\n" \
               "Link part of it into a space: ovm link add <dir> --to <source>/<ws>/<space>"
}

post_remove() {
  anfs_callback_unregister wsm "$PPM_CURRENT_PACKAGE"
  user_message "Left in place: your vaults, their ovm.yml, and the links in your spaces.\n" \
               "The registry is in \$XDG_STATE_HOME/ovm."
}

# From pvm, once: when $XDG_STATE_HOME/pvm is there and $XDG_STATE_HOME/ovm is not, move it, then
# rename pvm.yml to ovm.yml in each registered vault that answers within OVM_PROBE_SECONDS (3)
# and has no ovm.yml. Ids are kept, so the registry, the links and the document ids stay valid.
# One line per vault renamed or left; nothing at all when there is nothing to carry over.
_ovm_migrate() {
  local state="${XDG_STATE_HOME:-$HOME/.local/state}"
  local old="$state/pvm" new="${OVM_STATE_HOME:-$state/ovm}"
  local id name added path
  [[ -d "$old" ]] || return 0
  if [[ -e "$new" ]]; then
    user_message "Both $old and $new exist: nothing was carried over from pvm. " \
                 "Merge them by hand, then delete $old."
    return 0
  fi
  mkdir -p "$(dirname "$new")"
  mv "$old" "$new" || { user_message "Could not move $old to $new: carry it over by hand."; return 0; }
  [[ -f "$new/vaults" ]] || return 0
  while IFS=$'\t' read -r id name added path || [[ -n "$id" ]]; do
    [[ "$path" == /* ]] || continue
    # The same probe as ovm's _reachable: a vault on a hung iCloud or network mount must not
    # hang the install
    if ! perl -e 'alarm shift; stat $ARGV[0]; exit 0' "${OVM_PROBE_SECONDS:-3}" "$path/pvm.yml" 2>/dev/null \
       || [[ ! -d "$path" ]]; then
      user_message "Vault $name ($id) at $path did not answer: rename its pvm.yml to ovm.yml by hand."
      continue
    fi
    [[ -f "$path/pvm.yml" && ! -e "$path/ovm.yml" ]] || continue
    if mv "$path/pvm.yml" "$path/ovm.yml"; then
      user_message "Vault $name ($id): renamed pvm.yml to ovm.yml in $path"
    else
      user_message "Vault $name ($id) at $path: rename its pvm.yml to ovm.yml by hand."
    fi
  done < "$new/vaults"
  return 0
}
