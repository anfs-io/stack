# stack/obsidian
#
# Installs ovm (~/.local/bin/ovm), the Obsidian Vault Manager: documentation vaults (Obsidian or
# plain markdown) whose directories are linked into wsm spaces, and whose documents are found by
# a stable id. The nvim plugin config and the `ob` alias are stowed with it.
#
# ovm listens to wsm (lib/anfs/callbacks.sh): when wsm installs a space, ovm creates the links
# that point into it; when wsm removes one, ovm removes them. wsm knows nothing about ovm. The
# registration is kept by anfs, so it outlives a wsm implode and goes when ovm is removed.

post_install() {
  anfs_callback_register wsm "$PPM_CURRENT_PACKAGE" "ovm link apply --event"
  user_message "Vaults are the entries of ~/vaults: ovm new <name>, or link a directory there and ovm init it\n" \
               "Link part of it into a space: ovm link add <dir> --to <source>/<ws>/<space>"
}

post_remove() {
  anfs_callback_unregister wsm "$PPM_CURRENT_PACKAGE"
  user_message "Left in place: ~/vaults, your vaults' ovm.yml, and the links in your spaces.\n" \
               "The record of those links is in \$XDG_STATE_HOME/ovm."
}
