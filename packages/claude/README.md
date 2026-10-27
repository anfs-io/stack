# claude

Claude Code, installed by mise (`.config/mise/conf.d/claude.toml`), the `cc` shortcuts (`.config/zsh/claude.zsh`), the plugin search paths (`.config/claude/plugins.d/`), and anfs's coordinator adapter for Claude Code. The marketplaces' clones are `install.sh`'s `x_install`, which ppm does not run (off).

## The coordinator adapter

Core does not depend on any one coding agent: it owns what every harness uses (leases, events, `wsm listen --hook`, each space's `coordinator:` policy, anfsd's inbox summary), and the glue for one harness is that harness's package. This is Claude Code's (agents/06b, 06b2, the status line; moved out of core/anfs and core/wsm by agents/06's to-stack). Both scripts source core's `~/.local/lib/anfs/*.sh`.

| Path | What |
| --- | --- |
| `~/.local/lib/claude/anfs/hook <entry>` | The adapter, run by Claude Code from the hooks below: claims and holds a space's `coordinator` lease for its session, listens for the space's events, prints the inbox line and the status line |
| `~/.local/lib/claude/anfs/settings install\|remove\|status` | The writer of those hooks and the status line into `~/.claude/settings.json`; `post_install` runs `install`, `post_remove` runs `remove` (the package's own copy: `post_remove` runs after the unstow) |
| `~/.config/claude-anfs/claude-anfs.env` | Its one setting, `CLAUDE_ANFS_STATUSLINE` (`on` by default) |

### ~/.claude/settings.json

- User scope: one place, every session on the machine. The package keeps **its own hooks, and nothing else**, there: the file is merged, never overwritten (Claude Code writes it too, `/config`); the person's keys and hooks (herdr's) stay, theirs first in an event's list.
- Its own are the handlers whose `command` ends `/claude/anfs/hook`: the adapter's absolute path, exec form (`args`, no shell): SessionStart `session-start` (10 s) and `listen --max 86340` (`asyncRewake`, timeout 86400), Stop `listen` (the same), UserPromptSubmit `prompt` (5 s), SessionEnd `session-end` (3 s), the same for every space.
- Unchanged: not rewritten (`claude settings: up to date`). A file that is not a JSON object, or `settings.json` as a link, is refused, saying so (exit 1; ppm reports it). Remove deletes the file when nothing else is left in it, never `~/.claude/`. `settings.local.json` is never read or written, nor any space's `.claude/`.
- `settings status` prints `claude settings: <state> (~/.claude/settings.json)`: `ok`, `missing` (none of ours there: Claude Code may not be used), or `outdated`, `invalid`, `refused`, which also warn, naming the fix, and exit 1.

### The status line

- In the same writes: `"statusLine": {"type": "command", "command": "'<hook>' statusline"}` (statusLine has no `args`: its command runs in a shell, so the path is single-quoted). Ours is the one whose command ends in the adapter's path and `statusline`; it is written when the file has no statusLine or has ours (assigned in place: its position kept), and taken out by `remove` and by `CLAUDE_ANFS_STATUSLINE=off` (any other value warns and counts as off).
- Every session in a space shows the space and its role there: `space: lgat/next role: coordinator` in the session that holds the space's coordinator role, `space: lgat/next role: none` in the others; outside the spaces nothing (nor in runs, or without `WSM_SPACES_HOME`). Claude Code watches the file: a running session picks up a changed `statusLine` without a restart.
- Turn it off with `~/.local/lib/claude/anfs/settings config set CLAUDE_ANFS_STATUSLINE=off`: that writes `claude-anfs.local.env` and rewrites `~/.claude/settings.json` at once (the hooks stay); `config unset CLAUDE_ANFS_STATUSLINE` puts it back. The script's settings are core's `config` group under the tool name `claude-anfs` (`anfs config list --all` shows them). A value in the environment wins over the files, as with every setting; a value changed by hand in the file is written by the next `settings install` (`settings status` says `outdated` until then).
- A status line of your own is never touched: install keeps it and prints one line on how to compose. Have your script run ours with the same input and print what it prints, e.g.:

```bash
#!/usr/bin/env bash
input=$(cat)
echo "your line"
printf '%s' "$input" | ~/.local/lib/claude/anfs/hook statusline   # space: <space> role: coordinator|none, or nothing
```

### The hook

- **Cheap outside the spaces**: its first lines, before any library is sourced, exit 0 unless `$PWD` (or the physical directory, `cd -P .`, no fork) is `$WSM_SPACES_HOME` or below it (`~` expanded). core/wsm's `sh/wsm.sh` exports `WSM_SPACES_HOME` once per shell, so Claude Code and its hooks inherit it; unset (Claude Code not started from such a shell: a GUI app), that one call asks `wsm config get WSM_SPACES_HOME` (the slow path).
- It reads the hook's JSON on stdin with bash patterns (no jq, no wsm or yq on the prompt path). The space is the one at or above the input's `cwd`, with an id; its policy the `coordinator.policy` wsm install records beside the lease (`claude hooks`, `claude task` or `none`; none recorded: `claude hooks`).
- The holder is the input's `session_id` and the **verified Claude Code process**: the first ancestor within six levels whose command is `claude` (or a node running `claude-code/cli.js`), a shell wrapper skipped, `CLAUDE_PID` not trusted; none: nothing is claimed. Its events' actor is `claude:<session 8>`.
- `session-start`: claim `coordinator`, or the same holder again on `compact`/`resume`; print the brief (about six lines), or one line naming the live holder.
- `listen`: SessionStart claims when free, in parallel with `session-start`; Stop only the holder. It runs `wsm listen --hook --max <s>s` in the space; a SIGTERM (the hook's timeout) ends it with the listener; exit 2 with the batch, or with one line after `--max`; else 0; nothing under `claude task`.
- `prompt`: the holder: nothing, or under `claude task` a line when its listener is gone; a session that lost the lease: one line, once; a live holder elsewhere: nothing; free, released, expired or dead: claim and the takeover brief; then the inbox line.
- `session-end`: release when this session holds it (`reason` `clear` or `session-end`).
- `statusline`: the line above. It runs on every assistant message, so it reads the lease once and nothing more: no process walk, no `ps` (the pid's start time is not compared), no wsm (`WSM_SPACES_HOME` unset: nothing printed), no yq, no event; about 18 ms in a space, 12 outside, on macOS.
- Exit 0 always but `listen`'s 2; nothing at all inside a run (`ANFS_RUN`) or for a subagent's input (`agent_id`); only the inbox line with `ANFS_COORDINATOR=off` or `coordinator: none`.
- **Only a session at the space's root is a candidate**: its input's `cwd` is the directory of the deepest space at or above it (the strings, else the physical directories compared), so `~/spaces/lgat` is lgat's candidate and `~/spaces/lgat/next` lgat/next's. A session below the root never claims, takes over or listens, and skips the process walk; its `session-start` names the live holder, or says there is none and that a session at the root becomes it. A holder whose `cwd` later moves below the root stays the holder: silent prompts, Stop re-arms, SessionEnd releases.
- **The inbox line**: from anfsd's `~/.local/state/anfsd/inbox/summary.json`, `anfs inbox: 2 waiting here (merge core +3 (r-20261024-2), install core/pcm), 1 elsewhere: anfs inbox`, printed when it differs from what this session last printed or every 30 minutes while items wait; nothing when nothing waits or anfsd never wrote the file. `ANFS_INBOX_HINT=off` for a session. Per session: `$ANFS_STATE_HOME/claude/<session id>.inbox` and `.lease` (removed at SessionEnd, a week-old one pruned at a SessionStart).

## Tests

`bats packages/claude/tests </dev/null`. They need a core checkout: `ANFS_TEST_LIB`'s (a core checkout's `lib/anfs`), else the core checkout beside this stack one, else the installed libraries' source; its wsm runs the spaces and the listener. `helper.bash` links the package and core into a temp HOME as ppm would, with every `XDG_*`, the anfs, wsm and claude-anfs homes, `ANFSD_STATE_HOME` and `WSM_SPACES_HOME` inside the test's temp directory (`claude_guard` checks), and unsets `ANFS_WORK`, a run's variables and every `CLAUDE*`.

- `hook.bats`: a fake Claude Code (a copy of bash named `claude` running a driver that runs the hook as its child on request through two FIFOs, so a session's hooks share its pid); fixture inputs and summaries; the listener's wake, rearm, takeover and death; an idle bound for a waiting `listen`; the `WSM_SPACES_HOME` gate before any library, with a copy of the hook whose libraries leave a mark; the recorded policy: `none`, `claude task`, none recorded; the `statusline` entry with `ps` and `wsm` stubs that leave a mark; candidates only at a space's root, a nested space's root its own, a holder below its root.
- `settings.bats`: the merge into the test HOME's `~/.claude/settings.json`, ownership, remove, refusals, `status`, `install.sh`'s hooks; the statusLine: default, off, the person's kept, `settings config set|unset`. jq checks the JSON.
