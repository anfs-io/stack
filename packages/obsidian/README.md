# obsidian

Obsidian for the terminal and the editor: the nvim plugin config (`oconf`), the `ob` and `cdi`
aliases on macOS, and `ovm`, the Obsidian Vault Manager.

## ovm

A vault is a directory of markdown documents with a `vault.yml` at its root: an Obsidian vault, a
plain tree, a git repo of docs. "Obsidian" is the name, not a restriction. Vaults are the entries
of `~/vaults` (`OVM_VAULTS_HOME`), as spaces are `~/spaces`': a directory there, or a link to one,
with a `vault.yml` (which carries the vault's id). `ls ~/vaults` is the list, and a vault is named
by its entry. There is no registry and nothing to scan: removing a vault from ovm is removing its
entry. A command run in a directory with a `vault.yml` that is not in `~/vaults` says to link it
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
ovm init [dir]                        # make an entry of ~/vaults a vault: vault.yml, a new id
ovm list                              # NAME ID STATUS (ok, unreachable, not a vault) PATH
ovm path [--dir] [vault-or-doc]       # a vault's path, or a document's by id (--dir: its directory)
ovm cd [vault-or-doc]                 # go there: a vault, or a document's directory
ovm docs [vault | vault/space | DIR]  # documents by their frontmatter id; --space <wsm space>
ovm show <id>
ovm validate [--fix] [--strict]       # documents against the vault's vocabulary
```

`ovm cd` is a shell function (`~/.config/sh/ovm.sh`, bash and zsh) through core's `_anfs_cd`,
like `wsm cd`: it goes where `ovm path --dir` says, a vault's directory or a document's, and with
no argument the vault you are in (outside one it fails and you stay put). It completes vault names.

### vault.yml

The vault's own concerns only: where its spaces are, what to skip, and the vocabulary its
documents are checked against. `ovm init` writes it (the keys below it leaves commented out), and
never rewrites one beyond minting a missing id.

```yaml
id: fl24qptnnh                   # the vault's identity: do not change it
spaces_path: spaces              # the folder whose subfolders are the vault spaces (default spaces)
exclude: [_templates, "*/drafts"] # what docs and validate skip (.obsidian/, .trash/ always)
required: [type, id]             # keys every document's frontmatter must have (default [type, id])
kinds:                           # allowed values of `type`; each may require more keys
  note: {}
  decision: {required: [status]}
fields:                          # the value type of a frontmatter key
  status: [proposed, accepted, superseded]   # a list: one of these
  timestamp: datetime            # string, number, bool, date, datetime, list
tags: [idea, decision, go]       # allowed tags, frontmatter and inline; a/b is allowed by a
spaces:                          # per vault space: more of the same vocabulary
  product: {tags: [linker, wsm]}
```

- `exclude:` patterns are matched against each path relative to the vault's root, as bash's
  `[[ $path == $pattern ]]` (so `*` crosses `/`); a matching directory is skipped whole. Hidden
  names and `node_modules` are always skipped.
- For a document in vault space S, `required` and `tags` are the vault's and S's together; `kinds`
  and `fields` are the vault's with S's entries replacing those of the same name.
- `ovm validate` reports, per document: no or unclosed frontmatter, YAML that does not parse, a
  missing required key, a `type` that is not one of `kinds` (when there are any) or lacks what
  its kind requires, a field whose value is not of its type (`string`: any single value; `number`;
  `bool`; `date`, `YYYY-MM-DD`; `datetime`, ISO 8601 with a time; `list`; or one of a list of
  values), a tag in `tags:` or inline (`#tag`, outside code) that is not listed and has no listed
  ancestor (when any tag is listed; `#go` is a tag like any other), and a duplicate id. And on
  `vault.yml` itself: an unknown key (the old `links:`, `profile:` and `items:` say what replaced
  them), a `spaces:` entry with no folder, an unknown field type, a `spaces_path` that is absolute,
  hidden or leaves the vault.

### Vault spaces and links.yml

A vault space is a folder directly under `spaces_path`: `<vault>/<space>`, or `<space>` in the
vault you are in. Which vault spaces show up in which wsm spaces is neither the vault's business
nor wsm's: it is yours, in `~/.config/ovm/links.yml`. Your repository's layer of this package can
ship it; one machine's additions go in `links.local.yml` beside it (it adds links, it cannot take
one away).

```yaml
- vault: apex                 # an entry of ~/vaults
  space: product              # a folder under that vault's spaces_path
  to: [anfs-dev, lgat/tech]   # wsm space ids (wsm ls)
  as: apex                    # optional: the link's name in each wsm space (default: the space's)
```

ovm reads each wsm space's directory from `wsm ls --json` and puts a relative symlink there
(`lib/anfs/link.sh`), so the documentation sits next to the code it describes. `ovm space link`,
`unlink` and `remove` are what write the files: `links.yml` when it is a file of its own (or
missing), `links.local.yml` when `links.yml` is a link (shipped), and they say so. A pair only the
shipped file declares is edited there. A file that does not read (an entry without `to`, an
unknown key) stops every `ovm space` command with 64, naming the entry.

```bash
ovm space list [vault]                # SPACE TO AS STATUS LINK VAULT; --problems: exit 1 on any
ovm space add <space>                 # make the folder (never writes vault.yml)
ovm space link <space> <wsm-space> [--as NAME]
ovm space unlink <space> [<wsm-space>]
ovm space remove <space>              # unlink it everywhere; the folder and its notes stay
ovm space apply                       # make every declared link that is missing on this machine
```

STATUS is `ok`, `pending` (the wsm space is not installed), `unlinked` (a folder no entry
names), `missing`, `conflict` (something else is at the link's path), `unknown` (no such wsm
space), `no folder`, `dangling` (the folder is gone, ovm's link is not), `no vault` (an entry
naming a vault not in `~/vaults`) or `orphan` (a link ovm made that no entry declares any more).

wsm tells ovm when a space is installed or removed: this package's `install.sh` registers
`ovm space apply --event` as a wsm listener (`anfs callbacks wsm` lists it under
`stack/obsidian`). wsm knows nothing about ovm or vaults.
