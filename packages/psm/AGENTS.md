# psm — Personal Skills Manager

Syncs agent skills to every AI agent ppm has installed, through the `skills`
CLI (`npx skills`). `psm help` documents the commands; this file covers what
the code and the usage text can't.

## Shipping a skill from a ppm package

Put it at `home/.local/share/psm/skills/<name>/SKILL.md`. stow projects it into
`~/.local/share/psm/skills`, which psm syncs as the `builtin` repo — no config
file, no entry anywhere, nothing to keep in step. Any number of packages can
contribute to the one hub; `ai/packages/chorus` and `pdt/packages/pcm` both do.

## What the skills CLI actually does

Found by experiment against `skills@latest` on 2026-09-15, none of it
documented upstream. Re-check it if the CLI changes.

- **Symlinked skill directories are invisible to it.** A hub of
  `hello -> …/pkg/hello` links yields `No skills found`; it filters directory
  entries without following links.
- **Symlinked *files* are followed.** A real `<name>/` holding a symlinked
  `SKILL.md` is found, and supporting files (`references/`, …) are copied
  through dereferenced. This is the only reason the hub works: ppm stows with
  `--no-folding`, so skill directories are real and only their files are links.
- **It copies, it does not link back to the source.** Editing a skill in its
  package changes nothing until `psm update` re-copies it.
- **`skills list --json` reports `source: none` for anything installed from a
  local path** (remote skills carry `owner/repo`). Hence `builtin` enumerates
  its skills by name instead of passing `-s '*'`: prune protects declared
  names, and a local `*` source would leave nothing to match against.
- **Agents are named two ways**: display name in `list --json` ("Claude Code"),
  id on the command line (`claude-code`). `_agent_display` maps between them and
  returns 1 for ids it doesn't know, so an unmapped agent gets re-added rather
  than wrongly skipped.

## Command surface

- Nouns take verbs: `repo`, `skills`, `agents`. A bare noun prints that group's
  usage; an unknown verb prints it to stderr and exits 1.
- `sync` and `update` stay top-level. Their argument is a *config* name, and
  they span all three nouns — read repos, install skills, target agents.
- `path` is plumbing for the `psm cd` function in `psm.zsh`, deliberately kept
  out of the usage and the completion.
- Commands name other commands in their output ("Run: psm skills prune"), so
  renaming one means grepping the strings, not just the dispatch.

## Two traps in the source

- `_config_sources` checks `yq` on its own rather than through the pipeline.
  Under `pipefail` a consumer that stops reading (`psm skills | head`) would
  otherwise surface as an unparseable config.
- For the same reason, never `return` early from a loop reading
  `< <(_config_sources)`: it closes the pipe under the writer, whose `yq` then
  fails and gets reported as a bad config. `_repo_config` drains, then returns.

## Deliberately not built

- Local `*` sources re-add on every sync, because psm can't enumerate them
  ahead of time. It could do what `_builtin_source` does and give them real
  `ok`/`missing` status — worth it if the re-adding becomes annoying.
- No way to scope a `builtin` skill to one agent; it goes to every detected
  agent. The escape hatch is an ordinary config entry pointing at the hub with
  an `agents:` key.
