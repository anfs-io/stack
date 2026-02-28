---
description: "Synthesize chorus/project.md from plan execution logs. Reads new log Context Updates and merges into the existing project context."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /project:summarize

Synthesize `chorus/project.md` — the living project context document — from plan execution logs.

## What This Does

This command maintains `chorus/project.md`, a synthesized document that describes the current state of the project based on all work that has been done. It is the accumulated context from all executed plans, written as a coherent snapshot — not a changelog.

`CLAUDE.md` at the project root should reference this file:

```markdown
## Project Context
For current project state derived from plan execution, see `chorus/project.md`.
```

## How It Works

1. Read `chorus/project.md` if it exists — this is the current baseline
2. Read `last_refreshed_at` from the frontmatter (or treat as epoch if first run)
3. Scan all `chorus/units/*/*/log.md` files
4. Filter to logs with `completed_at` newer than `last_refreshed_at`
5. Order the new logs chronologically by `completed_at`
6. Extract the `## Context Updates` section from each new log
7. Synthesize: take the existing `chorus/project.md` content plus the new context updates and produce an updated document
8. Write the updated `chorus/project.md` with a new `last_refreshed_at` timestamp

## The Synthesis Step

This is the critical part. You are NOT appending to a changelog. You are rewriting `chorus/project.md` as a coherent, current-state document that incorporates the new information.

Think of it like this: if a new Claude Code session reads only `CLAUDE.md` and `chorus/project.md`, it should understand the project as it exists right now — what models exist, what the architecture looks like, what CLI commands are available, what conventions are in use.

### Synthesis rules

- **Merge, don't append.** If the existing document says "the hierarchy is Space → Project → Tier" and a new log says "Tier has been renamed to Unit", the updated document should say "the hierarchy is Space → Project → Unit" — not both statements.
- **Replace stale information.** New context updates supersede old information on the same topic.
- **Preserve information not contradicted by updates.** If the existing document describes the testing setup and no new logs touch testing, keep that section as-is.
- **Keep it factual and concise.** This is a reference document, not a narrative. Short paragraphs, clear statements.
- **Organize by topic, not by time.** Group related information together (models, CLI commands, file structure, conventions) rather than by when it was added.
- **Omit ephemeral details.** Test counts, specific timing data, and implementation blow-by-blow don't belong here. Focus on architectural facts.

## File Format

```markdown
---
last_refreshed_at: "2026-02-27T14:30:00+08:00"
---

# Project Context — {project name}

## Architecture

Current models, their relationships, key design patterns...

## CLI Commands

Available commands, their usage...

## File Structure

Key directories, conventions, where things live...

## Conventions

Coding standards, naming patterns, workflow conventions...

## Dependencies

Key gems, external services, integrations...
```

The sections above are suggestions — adapt them to what makes sense for the project. A gem will have different sections than a web app. The first run will establish the structure based on what the initial logs describe; subsequent runs evolve it.

## First Run

If `chorus/project.md` does not exist:

1. Find ALL log.md files (no date filter — process everything)
2. Extract all `## Context Updates` sections
3. Synthesize a new document from scratch
4. Write `chorus/project.md` with `last_refreshed_at` set to now

## Subsequent Runs

1. Read existing `chorus/project.md`
2. Find logs newer than `last_refreshed_at`
3. If no new logs, report: **"No new logs since last refresh. chorus/project.md is current."**
4. If new logs found, synthesize and update

## Edge Cases

- **Log without `## Context Updates` section** — skip it with a note: "Log {path} has no Context Updates section, skipping." This can happen with logs written before this convention was introduced.
- **Log with `status: failed`** — still process its Context Updates if present. Failed plans may have made partial changes worth recording.
- **No logs exist at all** — report: **"No execution logs found. Run `/project:build` first."**
- **`completed_at` missing from a log** — use the log file's filesystem modification time as fallback.
- **Multiple logs with identical timestamps** — process in filesystem order (unit name, then plan number).

## After Summarizing

Report what was processed:

```
Refreshed chorus/project.md

Processed 3 new logs:
  hierarchy-refactor/01-naming-and-area (2026-02-27)
  hierarchy-refactor/02-chorus-yml-enrichment (2026-02-27)
  hierarchy-refactor/03-navigation-directives (2026-02-28)

chorus/project.md updated (last_refreshed_at: 2026-02-28T15:00:00+08:00)
```

## Examples

```
/project:summarize              # Process new logs and update chorus/project.md
```

No arguments. It always operates on the current project (determined by PWD).
