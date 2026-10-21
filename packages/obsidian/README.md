# obsidian

Obsidian for the terminal and the editor: the nvim plugin config (`oconf`), the `ob` and `cdi`
aliases on macOS, and `ovm`, the Obsidian Vault Manager.

## ovm

A vault is any directory of markdown documents with an `ovm.yml` at its root: an Obsidian vault,
a plain tree, a git repo of docs. "Obsidian" is the name, not a restriction. Vaults live
anywhere; the marker is the source of truth and carries the vault's id, and a registry
(`$XDG_STATE_HOME/ovm/vaults`) indexes the ones this machine knows. `ovm scan` rebuilds it, and a
vault you stand in is registered as you use it. A vault found at a new path is the same vault,
moved.

```bash
ovm init [dir] [--name NAME]          # make a directory a vault: ovm.yml, a new id, registered
ovm new <dir>                         # create the directory and init it
ovm list [--stale]                    # NAME ID STATUS PATH
ovm scan [dir...]                     # find ovm.yml under the directories (default ~)
ovm remove <vault>; ovm prune         # drop registry entries; the files are untouched
ovm path [vault-or-doc]               # a vault's path, or a document's by id
ovm docs; ovm show <id>               # documents by their frontmatter id
ovm validate [--fix] [--strict]       # documents against the vault's profile
```

### Links into spaces

`ovm.yml`'s `links:` map a vault directory to a wsm space (`wsm ls`: its id, `lgat` or
`lgat/tech/web`). ovm reads the space's directory from `wsm ls --json` and puts an absolute
symlink there, so the documentation sits next to the code it describes. The links are the
vault's; the symlinks are this machine's, and `ovm link apply` makes the missing ones.

```bash
ovm link add [dir] --to <spec> [--as NAME]
ovm link list [dir]                   # SOURCE TARGET AS STATUS LINK VAULT
ovm link remove [dir] [--to <spec>]
ovm link apply; ovm link validate
```

wsm tells ovm when a space is installed or removed: this package's `install.sh` registers
`ovm link apply --event` as a wsm listener (`anfs callbacks wsm` lists it under
`stack/obsidian`). wsm knows nothing about ovm.
