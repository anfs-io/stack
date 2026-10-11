# firstmate

[Firstmate](https://github.com/kunchenguid/firstmate) is an "agent distro". You talk to one
coding agent, the *first mate*. It turns your intent into tasks, dispatches crewmate agents into
isolated git worktrees, supervises them, and reports back. Merges and destructive actions wait
for your word. This package runs it on the **herdr** backend. The reasons for that choice are in
`anfs/orchestrators-eval.md`.

## What it installs

| Piece | How |
|---|---|
| Firstmate repo at `meta.firstmate.ref` | `install.sh` clones it into `~/.local/share/firstmate/repo`, detached at that ref |
| herdr, claude, node, git + gh, python | `depends:` (`ai/herdr`, `ai/claude`, `anfs/node`, `pde/git`, `pdt/python`) |
| treehouse, no-mistakes | mise `github:` backend (`firstmate.toml`) |
| tasks-axi, quota-axi, gh-axi, chrome-devtools-axi | mise `npm:` backend (`firstmate.toml`) |
| jq; perl + shasum on Linux | `brew:` / `system:` (no ppm package exists for them) |
| `firstmate` launcher | `~/.local/bin/firstmate` |

The axi tools' own `setup hooks` step is **deliberately not run**, because it writes global
agent-harness hooks. `lavish-axi` (optional HTML presentation boards) is left out.

## Use

```sh
firstmate doctor                      # tools, herdr, Claude auth
firstmate project add ~/spaces/x/repo # or a wsm space name; registered local-only
firstmate up                          # herdr session "firstmate", first mate in workspace "captain"
firstmate note docs/spec.md           # hand it a document
firstmate prompt "status?"            # or just type in the captain pane
firstmate status                      # agents and task states
firstmate down                        # stops the whole session: first mate, crew, supervisor
```

Operator state (backlog, briefs, reports, task state) lives in `FM_HOME`, which defaults to
`~/.local/share/firstmate/home`. `ppm remove ai/firstmate` deletes it along with the repo.

Every agent pane inherits the herdr server's environment, so the server starts with an
allowlisted one. The panes get the `PATH` of the shell that ran `firstmate up`, plus `HOME`,
`USER`, `SHELL`, `TERM`, `LANG`, `TMPDIR`, `FM_HOME`, the XDG dirs, `CLAUDE_CODE_OAUTH_TOKEN`,
`ANTHROPIC_API_KEY` and `DISABLE_AUTOUPDATER`. Nothing else is passed through, so a parent
harness's variables (e.g. `CLAUDE_CODE_*` when started from inside Claude Code) do not leak.

## Upgrading Firstmate

Change `meta.firstmate.ref` in `package.yml` to a newer commit and run `ppm install ai/firstmate`.
The checkout moves to the new ref. Firstmate moves fast, so pinning keeps upgrades deliberate.
herdr comes from brew and is not pinned. The `factory-e2e` unit (`ai/chorus/units/`) catches
drift between the two.
