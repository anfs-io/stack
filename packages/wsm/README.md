# wsm — work space manager

A registry of the workspaces under your home directory, so you can jump to one by name without
remembering where it lives and without walking the filesystem.

A workspace is any directory holding a `.wsm/id` marker. The marker is the source of truth; the
registry at `${XDG_STATE_HOME:-~/.local/state}/wsm/workspaces` only indexes it, and can be thrown
away and rebuilt with `wsm scan` at any time.

`docs/spec.md` is the specification, including the places this implementation deliberately
departs from it.

## Getting started

```sh
ppm install wsm
wsm scan                 # seed the registry from markers already on this machine
```

Then, in a directory you want to track:

```sh
wsm init                 # added <name> ~/path/to/it
wsm cd <name>            # jump to it from anywhere
```

`wsm cd` needs the shell function in `~/.config/sh/wsm.sh` — a subshell cannot change its
parent's directory, so the binary prints the path and the shell does the `cd`. Both the zsh and
the bash rc source it. With no shell package installed, use `cd "$(wsm path <name>)"`.

## Commands

| Command | What it does |
| --- | --- |
| `wsm init [DIR] [--name NAME]` | Mark `DIR` (default `.`) as a workspace and register it |
| `wsm new PATH [--name NAME]` | Create `PATH`, then behave like `init` |
| `wsm ls [--stale\|--all] [--paths\|--ids]` | List registered workspaces |
| `wsm cd [QUERY]` | Jump to a workspace; with no `QUERY`, to the root of the current one |
| `wsm path [QUERY]` | Print a workspace path (what `cd` is built on) |
| `wsm forget [QUERY]` | Drop an entry, leaving its marker in place |
| `wsm prune [--dry-run]` | Drop every stale entry |
| `wsm scan [DIR...] [--dry-run]` | Search for markers and register what it finds |
| `wsm prepare [DIR] [--dry-run]` | Clone the repos this workspace declares |

`QUERY` resolves in this order: an exact id, then a unique id prefix of at least four characters,
then an exact name. Names do not have to be unique — an ambiguous query lists the candidates and
exits 2 rather than guessing.

Any command run inside an unregistered workspace registers it, so a freshly cloned repository
with a committed `.wsm/id` appears the first time you run any `wsm` command in it.

## Filling a workspace in: `.wsm/resources`

A workspace can declare what belongs inside it. `wsm prepare` clones what is missing and leaves
alone what is already there — it never pulls, because what is checked out is yours.

```yaml
# ~/spaces/rws/.wsm/resources
resources:
  - type: repo
    url: git@github.com:maxcole/rws-pcs
    path: repos/pcs
  - type: repo
    url: git@github.com:maxcole/pcs.infra
    path: repos/infra
    ref: main              # optional; a branch, tag or commit, checked out after the clone
```

`type` defaults to `repo`, the only type implemented. It is carried from the start so `link`,
`mkdir` and whatever else can arrive later without invalidating files already written; an unknown
type is a warning and a skip, not an error.

Paths are relative to the **workspace root** and may not escape it. Commit this file — that is the
point: cloning the space on another machine and running `wsm prepare` rebuilds it.

**`prepare` is the one command that needs `yq`.** Everything else is plain bash. It is not
declared as a dependency because `yq` is a bootstrap formula ppm's own installer owns, and
declaring it would let `ppm remove` take it away.

## Building a whole space from a ppm package

The package ships a handler for ppm's declared-resource mechanism, so `wsm:` becomes a
`package.yml` key and a space becomes a declaration:

```yaml
# pde-ppm/packages/rws/package.yml — or any repo of yours
version: 0.1.0
author: you
depends: [wsm]
wsm:
  - repo_url: git@github.com:maxcole/rws-space
    path: spaces/rws
```

`ppm install rws` clones that repo to `~/spaces/rws`, registers it as a workspace, and runs
`wsm prepare` inside it — which clones whatever the space's own `.wsm/resources` declares. Commit
`.wsm/id` in the space repo and the workspace keeps the same identity on every machine.

Note the two bases for `path`. In `package.yml` it is relative to `$HOME`, because that entry
decides *where a space lives*. In `.wsm/resources` it is relative to the workspace root, because
that file describes *what is inside one*.

**`ppm remove` never deletes a space.** It reports the paths and leaves them. `ppm remove -f`
deletes them, but only what is recoverable: every git repo under the space is checked, and
anything with uncommitted changes, untracked files, commits that are on no remote, or no remote at
all is kept and named. A nested clone is not counted as untracked work of the space around it —
it gets assessed on its own.

## Things worth knowing

**Renaming.** There is no `rename` command because `init` already is one:

```sh
cd ~/code/thing && wsm init --name something-else
```

**Moving.** Just move the directory and run `wsm init` in its new home, or `wsm scan`. The id in
the marker is what identifies a workspace, so the entry is updated rather than duplicated and the
date it was first registered is kept.

**Forget is not delete.** `wsm forget` drops the registry entry but leaves `.wsm/` alone, so the
workspace re-registers itself the next time you run a `wsm` command inside it. That is deliberate.
To be rid of it for good, remove the marker: `rm -r .wsm`.

**Staleness costs a read.** An entry is stale when its path is gone or its marker no longer holds
the recorded id. Checking the second half means reading `<path>/.wsm/id`, so plain `wsm ls` does
one open+read per entry — fine for hundreds of workspaces, but it is not free. `wsm ls --all
--paths` filters and annotates nothing, so it skips validation entirely:

```sh
cd "$(wsm ls --all --paths | fzf)"
```

**Exit codes.** `0` success, `1` not found, `2` ambiguous, `3` matched but stale (the path is
still printed), `64` usage, `65` bad marker or registry data, `69` `prepare` needs yq or git and
neither is there, `73` target exists, `75` could not lock.

## Tests

```sh
bats packages/wsm/tests/
```

The suite runs the script straight out of the package with `HOME` and `XDG_STATE_HOME` pointed at
a temporary directory, so it never touches your real registry. One test deliberately waits out
the five-second lock timeout.
