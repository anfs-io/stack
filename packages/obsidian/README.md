# obsidian

Obsidian for the terminal and the editor: the nvim plugin config (`oconf`), the `ob` and `cdi`
aliases on macOS, and `ovm`, the Obsidian Vault Manager.

## ovm

A vault is a directory of markdown documents with an `ovm.yml` at its root: an Obsidian vault, a
plain tree, a git repo of docs. "Obsidian" is the name, not a restriction. Vaults are the entries
of `~/vaults` (`OVM_VAULTS_HOME`), as spaces are `~/spaces`': a directory there, or a link to one,
with an `ovm.yml` (which carries the vault's id). `ls ~/vaults` is the list, and a vault is named
by its entry. There is no registry and nothing to scan: removing a vault from ovm is removing its
entry. A command run in a directory with an `ovm.yml` that is not in `~/vaults` says to link it
there.

A vault stored elsewhere (iCloud) is a link in `~/vaults`, declared in your repository's layer of
this package (`<your repo>/packages/obsidian/package.yml`), so `ppm install obsidian` makes it:

```yaml
links:
  - src: ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/apex
    dest: vaults/apex
    platforms: [macos]
```

On a machine without that path the entry is `missing src` (`ppm show obsidian`), and a link whose
target is gone is `unreachable` in `ovm list`, as is a vault that does not answer within
`OVM_PROBE_SECONDS`. The settings (`OVM_VAULTS_HOME`, `OVM_PROBE_SECONDS`) are documented in
`~/.config/ovm/ovm.env`; this machine's values go in `ovm.local.env` beside it
(`ovm config set OVM_VAULTS_HOME=~/notes`).

```bash
ovm new <name>                        # create ~/vaults/<name> and init it
ovm init [dir]                        # make an entry of ~/vaults a vault: ovm.yml, a new id
ovm list                              # NAME ID STATUS (ok, unreachable, not a vault) PATH
ovm path [--dir] [vault-or-doc]       # a vault's path, or a document's by id (--dir: its directory)
ovm cd [vault-or-doc]                 # go there: a vault, or a document's directory
ovm docs; ovm show <id>               # documents by their frontmatter id
ovm validate [--fix] [--strict]       # documents against the vault's profile
```

`ovm cd` is a shell function (`~/.config/sh/ovm.sh`, bash and zsh) through core's `_anfs_cd`,
like `wsm cd`: it goes where `ovm path --dir` says, a vault's directory or a document's, and with
no argument the vault you are in (outside one it fails and you stay put). It completes vault names.

### Links into spaces

`ovm.yml`'s `links:` map a vault directory to a wsm space (`wsm ls`: its id, `lgat` or
`lgat/tech/web`). ovm reads the space's directory from `wsm ls --json` and puts a relative
symlink there (as every link the toolkit makes, `lib/anfs/link.sh`; one made absolute before is
still `ok`), so the documentation sits next to the code it describes. The links are the
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
