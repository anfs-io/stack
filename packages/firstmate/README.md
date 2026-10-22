# firstmate

[Firstmate](https://github.com/kunchenguid/firstmate) is an "agent distro". You talk to one
coding agent, the *first mate*. It turns your intent into tasks, dispatches crewmate agents into
isolated git worktrees, supervises them, and reports back. Merges and destructive actions wait
for your word. This package runs it on the **herdr** backend. The reasons for that choice are in
`core/chorus/orchestrators-eval.md`.

## What it installs

| Piece | How |
|---|---|
| Firstmate repo at `meta.firstmate.ref` | `install.sh` clones it into `~/.local/share/firstmate/repo`, detached at that ref |
| herdr, claude, node, git + gh, python | `depends:` (`herdr`, `claude`, `node`, `git`, `python`) |
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

`firstmate up` writes one thing outside its own directories, on purpose: Claude Code's trust
for the repo (`projects.<root>.hasTrustDialogAccepted` in `~/.claude.json`, `trust_root`), since
`--dangerously-skip-permissions` does not skip that dialog. It is Claude Code's file, mostly its
state; nothing else of it is touched.

Operator state (backlog, briefs, reports, task state) lives in `FM_HOME`, which defaults to
`~/.local/share/firstmate/home`. `ppm remove stack/firstmate` deletes it along with the repo.

Every agent pane inherits the herdr server's environment, so the server starts with an
allowlisted one. The panes get the `PATH` of the shell that ran `firstmate up`, plus `HOME`,
`USER`, `SHELL`, `TERM`, `LANG`, `TMPDIR`, `FM_HOME`, the XDG dirs, `CLAUDE_CODE_OAUTH_TOKEN`,
`ANTHROPIC_API_KEY` and `DISABLE_AUTOUPDATER`. Nothing else is passed through, so a parent
harness's variables (e.g. `CLAUDE_CODE_*` when started from inside Claude Code) do not leak.

## Upgrading Firstmate

Change `meta.firstmate.ref` in `package.yml` to a newer commit and run `ppm install stack/firstmate`.
The checkout moves to the new ref. Firstmate moves fast, so pinning keeps upgrades deliberate.
herdr comes from brew and is not pinned. The `factory-e2e` unit (`stack/chorus/units/`) catches
drift between the two.
