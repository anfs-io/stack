# wsm: Workspace Registry Specification

## Overview

`wsm` manages workspaces that can live anywhere under the user's home directory, at any depth. It does not search the filesystem on every invocation. Instead it keeps a **registry** (an index of known workspaces), and each workspace carries a **marker** that identifies it. The marker is the source of truth; the registry is a rebuildable cache.

This spec was written to be language-agnostic. What ships in this package is a single `bash` implementation, `home/.local/bin/wsm`, written for bash 3.2 so it runs on a stock macOS as well as on Linux. The on-disk formats below are the contract: anything else reading them must agree byte for byte.

## Goals

- `wsm ls` is fast and never walks the filesystem.
- Workspaces register themselves through `init`, `new`, or automatically when wsm is run inside one.
- Moving a workspace does not create duplicates.
- A lost or corrupted registry can be rebuilt with an explicit scan.
- Everything works with only the utilities a stock macOS or Debian has: `find`, `date`, `sort`, `od`, `cut`.

## Non-Goals

- What a wsm workspace *contains* beyond the marker. Other wsm features may add to the workspace; this spec covers only registration and lookup.
- Syncing the registry across machines.

---

## 1. Workspace Marker

A directory is a wsm workspace if and only if it contains:

```
<workspace-root>/.wsm/id
```

`id` is a text file containing a single line: the workspace ID, followed by a newline.

### 1.1 Workspace ID

- Format: lowercase UUID, e.g. `3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c`.
- Generated once at `init` or `new` time and **never changed**.
- It identifies the workspace across moves and renames.

Generation, in order of preference — each is tried in turn:

1. `uuidgen` output, lowercased.
2. The contents of `/proc/sys/kernel/random/uuid` (Linux).
3. 16 random bytes from `/dev/urandom` formatted as a v4 UUID (e.g. via `od -An -tx1`).

### 1.2 Validation

When reading an `id` file, trim surrounding whitespace. The result must match `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`. Anything else means the marker is invalid, which wsm reports as an error without silently replacing it.

### 1.3 Other Contents

`.wsm/` may hold other files added by other wsm features. Registry code must only read or write `.wsm/id` and must ignore everything else in the directory.

---

## 2. Registry

### 2.1 Location

```
${XDG_STATE_HOME:-$HOME/.local/state}/wsm/workspaces
```

If `XDG_STATE_HOME` is set but empty, treat it as unset. Create the `wsm/` directory (mode `0700`) when writing if it does not exist. If the registry file is missing, treat that as an empty registry, not as an error.

### 2.2 Format

UTF-8 text with one workspace per line and **tab-separated** fields:

```
<id>\t<name>\t<added>\t<path>
```

| Field   | Description |
|---------|-------------|
| `id`    | Workspace ID from the marker. |
| `name`  | Display name. Defaults to the basename of `path`. Must not contain a tab, a newline, or `/`. |
| `added` | UTC timestamp when first registered, formatted `YYYY-MM-DDTHH:MM:SSZ`. |
| `path`  | Canonical absolute path to the workspace root. |

`path` is the **last** field so that it may contain spaces. Paths that contain a tab or a newline are rejected at registration time with an error.

Additional rules:

- Lines starting with `#` and blank lines are ignored when reading and are **not** preserved when writing.
- No header line.
- Sort lines by `name`, then by `path`, when writing. This keeps diffs stable.
- `id` is unique within the file. `path` is unique within the file. `name` is **not** required to be unique.

Example:

```
3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c	chorus	2026-09-24T10:12:00Z	/Users/roberto/code/anfs/chorus
9c1d2e3f-4a5b-4c6d-8e7f-0a1b2c3d4e5f	api	2026-09-20T08:01:44Z	/Users/roberto/work/roteoh/api
```

### 2.3 Path Canonicalization

Before a path is stored or compared, it must be canonicalized: made absolute, with symlinks resolved, and with no trailing slash (except for `/` itself).

`(cd -P -- "$dir" && pwd -P)`. Not `realpath` or `readlink -f`: neither is POSIX and their flags differ between macOS and Linux.

For **display only**, replace a leading `$HOME/` with `~/`. The stored value is always the full absolute path.

### 2.4 Writes: Atomicity and Locking

Every write follows this sequence:

1. Acquire the lock: `mkdir "$state_dir/workspaces.lock"` succeeds atomically. If it already exists, retry every 100 ms for up to 5 seconds, then fail with exit code 75. If the lock directory is older than 60 seconds, treat it as stale, remove it, and retry once.
2. Re-read the registry (it may have changed while waiting for the lock).
3. Apply the change in memory.
4. Write the full new contents to `workspaces.tmp.<pid>` in the same directory.
5. `mv` (rename) the temp file over `workspaces`.
6. Remove the lock directory. This must also happen on error or signal (`trap ... EXIT INT TERM HUP`).

Reads do not take the lock.

---

## 3. Workspace Discovery (Walk-Up)

`find_project_root(start_dir)`:

1. Canonicalize `start_dir`.
2. If `<dir>/.wsm/id` exists as a regular file, return `dir`.
3. If `dir` is `/` or equals `$HOME`'s parent, stop and return "not found". Otherwise set `dir` to its parent and go back to step 2.

Checking `$HOME` itself is allowed; walking above it is not.

---

## 4. Core Operation: `register(root, name?)`

Used by `init`, `new`, `scan`, and auto-registration.

1. Canonicalize `root`. It must be inside `$HOME` (equal to `$HOME` or starting with `$HOME/`); otherwise error.
2. Read and validate `root/.wsm/id`.
3. Under the lock:
   - **ID exists with the same path:** no change. If `name` was given explicitly and differs, update the name.
   - **ID exists with a different path:** the workspace moved. Update the path (and the name, if one was given). Keep the original `added`. Report `moved: <old> -> <new>`.
   - **Path exists with a different ID:** the directory's marker was replaced (for example, the workspace was deleted and re-created). Replace that entry with the new ID and `added = now`.
   - **Neither exists:** append a new entry with `added = now` and `name = name || basename(root)`.
4. Return the resulting status, one of `added`, `moved`, `updated`, or `unchanged`.

---

## 5. Commands

Normal output goes to stdout. Errors and warnings go to stderr, prefixed with `wsm: `.

### 5.1 `wsm init [DIR] [--name NAME]`

Turns `DIR` (default: the current directory) into a wsm workspace and registers it.

- If `DIR/.wsm/id` does not exist, create `.wsm/` and write a new ID.
- If it exists and is valid, keep it. This is the case for a freshly cloned workspace.
- If it exists and is invalid, exit 65.
- Call `register`.
- Output: one line, `<status> <name> <display-path>`.

Idempotent: running it twice leaves the registry and marker unchanged.

### 5.2 `wsm new PATH [--name NAME]`

- `PATH` is relative to the current directory or absolute. It must not already exist; if it does, exit 73.
- Create the directory (including parents), then behave exactly like `wsm init PATH`.
- Any other scaffolding `new` performs is out of scope here, but registration must happen **after** the directory and marker exist.

### 5.3 `wsm ls [--stale | --all] [--paths | --ids]`

Lists workspaces from the registry only. It performs no filesystem walk; the only filesystem access is a per-entry stat to check validity.

An entry is **stale** if either:

- `path` does not exist or is not a directory, or
- `path/.wsm/id` is missing or does not contain the entry's ID.

Filters:

| Flag      | Shows |
|-----------|-------|
| (default) | Valid entries only. |
| `--stale` | Stale entries only. |
| `--all`   | Both, with stale entries marked. |

Output modes:

- **Default:** aligned columns `NAME  PATH`, using the display path. With `--all`, stale rows get a trailing ` (stale)`. When stdout is not a TTY, print tab-separated values instead of aligned columns.
- **`--paths`:** one full absolute path per line, with no display shortening. Intended for piping, e.g. `wsm ls --paths | fzf`.
- **`--ids`:** one ID per line.

`--paths` and `--ids` are mutually exclusive; passing both exits with 64.

Exit status is 0 even when the list is empty.

### 5.4 `wsm path QUERY`

Prints the full absolute path of a single workspace, for use by a shell `cd` wrapper.

Resolution of `QUERY`, in order:

1. Exact ID match.
2. Unique ID prefix of at least 4 characters.
3. Exact `name` match.

Results:

- **Exactly one match:** print its path and exit 0.
- **No match:** exit 1.
- **Multiple matches:** exit 2 and print the candidates to stderr as `NAME  PATH`.

Stale entries are included in matching. If the matched entry is stale, print its path anyway, add a warning to stderr, and exit 3.

The shell helper this exists for is `wsm()` in `home/.config/sh/wsm.sh`, which intercepts
`wsm cd`. Note that the obvious form is wrong:

```sh
# Broken: exit 3 means "matched, but stale" and the path WAS printed, yet && short-circuits
wcd() { d=$(wsm path "$1") && cd "$d"; }
```

See deviation 2 in section 11.

### 5.5 `wsm forget [QUERY]`

Removes an entry from the registry. **Never touches the workspace directory or its marker.**

- `QUERY` resolves the same way as in `wsm path`. If omitted, use the workspace found by walking up from the current directory.
- An ambiguous query exits 2 without making changes.
- Output: `forgot <name> <display-path>`.

Because the marker stays in place, the workspace will re-register automatically if wsm is later run inside it (see §6). This is intended behavior. Document it, and point users to `rm -r .wsm` if they want the workspace gone for good.

### 5.6 `wsm prune [--dry-run]`

Removes all stale entries in a single locked write.

- Prints `pruned <name> <display-path>` for each entry removed.
- With `--dry-run`, prints `would prune ...` lines and writes nothing.

### 5.7 `wsm scan [DIR...] [--dry-run]`

Opt-in deep search, used to rebuild or augment the registry. `DIR` defaults to `$HOME`.

- Find every `.wsm` directory that contains an `id` file.
- Skip these directory names while descending: `.git`, `node_modules`, `vendor`, `.cache`, `Library` (macOS), `.Trash`.
- Do not follow symlinks.
- Call `register` for each workspace root found. Batch all changes into a **single** locked write.
- Print one status line per workspace, then a summary: `N added, N moved, N unchanged`.
- Invalid markers are reported as warnings and skipped.

Implementation note:

```sh
find "$dir" \( -name .git -o -name node_modules ... \) -prune -o -type d -name .wsm -print
```

### 5.8 `wsm help`, `wsm --version`

Standard.

---

## 6. Auto-Registration

On **every** wsm invocation except `forget`, `prune`, `scan`, `help`, and `--version`:

1. Run `find_project_root($PWD)`.
2. If a workspace is found and its ID is not in the registry, or is registered with a different path, call `register` for it.
3. Only take the lock and write when a change is actually needed. The common case (already registered) must not write.
4. Print nothing on success. If registration fails, print a warning to stderr and continue with the requested command; do not exit.

With this in place, a cloned workspace registers itself the first time any wsm command is run inside it.

---

## 7. Exit Codes

| Code | Meaning |
|------|---------|
| 0  | Success |
| 1  | Not found |
| 2  | Ambiguous query |
| 3  | Matched entry is stale (`path`) |
| 64 | Usage error (bad flags or arguments) |
| 65 | Invalid marker or registry data |
| 73 | Target already exists (`new`) |
| 75 | Could not acquire lock |

---

## 8. Robustness Rules

- **Malformed registry lines** (wrong field count, invalid ID, relative path): skip with a stderr warning that includes the line number. When writing, drop them and print a notice.
- **Duplicate IDs or paths found on read:** keep the first occurrence and warn. The next write de-duplicates.
- **Tabs or newlines in a name** supplied via `--name`: reject with exit 64.
- **Environment:** do not depend on the locale. Force `LC_ALL=C` in the shell implementations when sorting.
- **Permissions:** the registry file is created with mode `0600`.

---

## 9. Conformance Tests

`tests/*.bats` is the suite, run with `bats packages/wsm/tests/`. It runs the `wsm` executable straight out of the package, with `HOME` and `XDG_STATE_HOME` pointed at bats' per-test temporary directory, so it never touches the real registry.

Required cases:

1. `init` in a fresh directory creates `.wsm/id`, adds a registry line, and prints `added`.
2. Running `init` a second time is a no-op: `unchanged`, registry byte-identical.
3. `init` on a directory with an existing valid marker (simulated clone) keeps the ID and registers it.
4. Moving a workspace (`mv`) and running `init` in the new location updates the path and keeps `added`, with no duplicate entry.
5. `new` creates the directory and registers it. `new` on an existing path exits 73.
6. `ls` shows valid entries only. After `rm -rf` of a workspace, `ls --stale` shows it and `ls` does not.
7. `prune --dry-run` writes nothing. `prune` removes stale entries.
8. `path` resolves by name, by ID, and by ID prefix. Duplicate names exit 2 and list the candidates.
9. `forget` removes the entry and leaves the marker. A later wsm command run inside the workspace re-registers it.
10. Auto-registration: `cd` into an unregistered workspace with a marker, run `wsm ls`, and the workspace appears. When already registered, the registry's mtime does not change.
11. `scan` rebuilds a deleted registry, skips `node_modules/.wsm`, and does not follow symlinks.
12. Paths containing spaces round-trip correctly. A path containing a tab is rejected.
13. A malformed registry line produces a warning and is skipped. Other entries still list.
14. Concurrency: 10 parallel `init` runs in 10 different directories yield exactly 10 entries and a leftover-free state directory (no lock, no temp files).
15. `XDG_STATE_HOME` set to an empty string falls back to `~/.local/state`.

---

## 10. Workspace Resources (added after the original spec)

A workspace may declare what belongs inside it, in `<root>/.wsm/resources` (`.wsm/resources.yml`
is also accepted). This is the only part of wsm that reads YAML, and so the only part that needs
`yq`.

```yaml
resources:
  - type: repo          # the only type implemented; the default
    url: <git url>
    path: <relative to the workspace root>
    ref: <branch, tag or commit>    # optional, checked out after the clone
```

`type` is carried from the start so further types can arrive without invalidating files already
written. An unknown type is a warning and a skip, not an error. A `path` that is absolute or that
escapes the workspace is refused.

### `wsm prepare [DIR] [--dry-run]`

For each resource, in order:

- The target is already a git repo: report `present` and leave it. **No pull.** What is checked
  out belongs to the user, and a pull can conflict or fail; `ppm src update` is equally
  conservative about repos with local changes.
- The target exists and is not a git repo: report it, count a failure, carry on.
- Otherwise clone, then check out `ref` if one is given. A failed clone removes the partial
  directory so the next run is not blocked by it.

Prints one line per resource and a `N cloned, N present, N skipped, N failed` summary. Exit 0
unless something failed; exit 69 if `yq` or `git` is missing. A workspace with no resources file is
a silent no-op, because the ppm integration runs `prepare` after every clone.

### The `wsm:` package.yml key

`home/.local/lib/ppm/wsm.sh` registers `ppm_resource_wsm` with ppm's declared-resource mechanism
(see ppm's CLAUDE.md). A package may then be nothing but a declaration:

```yaml
depends: [wsm]
wsm:
  - repo_url: <git url>
    path: <relative to $HOME>
```

Installing it clones each repo, records the path in ppm's install tracker under `resources: wsm:`,
runs `wsm init` (idempotent, and a committed `.wsm/id` is kept, so identity survives the move to
another machine), then `wsm prepare`.

`repo_url` is optional. Without it the workspace must already exist at `$HOME/<path>`, which is
the case when the package stows `home/<path>/.wsm/` itself: the resource phase runs after stow.
The handler then skips straight to `wsm init` and `wsm prepare`. A path with neither a `repo_url`
nor anything stowed is an error naming the omission.

`path` is `$HOME`-relative here and workspace-relative in `.wsm/resources`. The first decides
where a space lives; the second describes what is inside one.

Both this handler and `prepare` read their entries one field per line
(`yq -r '... | [a, b] | .[]'`) rather than `@tsv`. Tab is IFS whitespace, so `IFS=$'\t' read`
collapses adjacent tabs and strips leading ones — an entry with a field left out would slide the
remaining values along by one, silently.

Removal never deletes a space. `ppm remove` reports the paths; `ppm remove -f` deletes only what
is recoverable — every git repo under the space is checked for uncommitted changes, untracked
files, commits on no remote, and a missing remote, and anything at risk is kept and named. A
nested clone does not make the space around it look dirty: under `git status --porcelain -uall` an
ordinary untracked directory expands to its files while a nested repo stays a single `?? path/`
entry, and those are dropped because the walk assesses each nested repo separately.

---

## 11. Where the Implementation Departs From This Spec

Each of these is a fix for a problem in the spec above, not a preference, and each is covered by
a test.

0. **`prepare` does auto-register (§6).** It is not on the exemption list: unlike `init`, it does
   not register anything explicitly, so it behaves like `ls` and `path`. Registering the workspace
   you are preparing is the wanted outcome.

1. **`init` and `new` do not auto-register (§6).** §6 exempts only `forget`, `prune`, `scan`,
   `help` and `--version`, but auto-registration walks up from `$PWD` — which for a bare
   `wsm init` is the very directory `init` is about to register. Auto-registration would do the
   work first and leave `init` reporting `unchanged` for a move it was asked to record.

2. **Exit 3 still lets you `cd` (§5.4).** A stale-but-matched entry prints its path *and* exits 3,
   so the spec's own `d=$(wsm path "$1") && cd "$d"` never cds. The exit code is kept — it is a
   real signal for scripts — and the `wsm()` shell function treats 0 and 3 alike, so you can
   always reach a stale workspace to fix it.

3. **Stale locks are detected with a file, not mtime (§2.4).** Reading a directory's age needs
   `stat`, whose flags differ between macOS and Linux and which is not POSIX. The lock holder
   writes epoch seconds to `<lock>/created` instead. That check runs *only* after the 5-second
   retry window has expired: during normal contention every waiter would otherwise see a
   just-created lock whose `created` file is not written yet, call it stale, and break it. That
   race cost one entry in ten in a parallel-init test before it was fixed.

4. **Auto-registration outside `$HOME` is silent (§3 vs §4).** The walk-up finds a workspace
   anywhere, but `register` refuses a root outside `$HOME`, so §6 as written would warn on every
   single invocation inside such a directory. It skips silently instead. An explicit `init` or
   `new` there still errors.

5. **The walk-up stops on `$HOME` itself (§3).** "`dir` is `/` or equals `$HOME`'s parent" is
   awkward, and walks all the way to `/` when the starting point is outside `$HOME`. Implemented
   as: check `dir`, then stop when `dir` is `$HOME` or `/`. `$HOME` is canonicalized once at
   startup, because it may itself contain a symlink (macOS `/var`, a home on a linked volume) and
   every stored path is canonical.

6. **Mode 0600 is set before the rename (§8).** Creating the temp file under `umask 077` rather
   than chmod-ing it afterwards, so the registry is never briefly world-readable.

7. **`scan` prints four counts (§5.7).** §4 defines four outcomes but §5.7 lists three; `updated`
   would otherwise vanish from the summary.

Two additions, both falling out of the spec rather than extending it:

- **`wsm path` with no QUERY** prints the root of the workspace containing the current directory,
  reusing the walk-up `forget` already defaults to. This is what makes a bare `wsm cd` jump to the
  workspace root.
- **`WSM_STATE_DIR`** overrides the state directory outright, which is what the tests use.

One clarification: §5.3 says the only filesystem access `ls` makes is "a per-entry stat", but the
staleness test compares the *contents* of `<path>/.wsm/id`, so it is an open+read per entry.
`wsm ls --all --paths` filters and annotates nothing, so it skips validation entirely and is the
cheap path for piping into `fzf`.
