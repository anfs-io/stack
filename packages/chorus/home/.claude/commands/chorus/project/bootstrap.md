---
description: "Bootstrap chorus/project.md for a project that has no project context file yet. Reads the codebase directly to generate the initial snapshot."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /project:bootstrap

Generate the initial `chorus/project.md` for a project that predates the summarize workflow. This is a one-time command — once `chorus/project.md` exists, use `/project:summarize` to keep it current from logs.

## When To Use

Use this when a project:
- Has no `chorus/project.md` yet
- Has existing code, tests, and possibly completed units/plans
- May have log.md files that lack `## Context Updates` sections (written before that convention)

## What You Do

You are in the root of a project. Your job is to understand the project as it exists right now and produce `chorus/project.md` — a concise, factual context document that gives the next Claude Code session everything it needs to work effectively.

## Step 1: Read Available Context

Read these files in order, skipping any that don't exist:

1. `CLAUDE.md` — the primary project context (always start here)
2. `chorus/units/*.md` — unit overviews (objectives, status)
3. `chorus/units/*/*/log.md` — any existing execution logs
4. `lib/**/*.rb` (or equivalent source directory) — scan the actual codebase structure
5. `spec/**/*_spec.rb` (or equivalent test directory) — understand test coverage
6. `Gemfile` or `package.json` or equivalent — dependencies
7. `.chorus.yml` — if present, project metadata

Do NOT read every file in detail. Scan directory trees for structure, read key files (models, main entry points, configuration) for substance. You're building a map, not memorizing the territory.

## Step 2: Synthesize

Write `chorus/project.md` as a coherent snapshot of the project's current state. The document should answer these questions for the next Claude Code session:

- What is this project and what does it do?
- What are the key architectural components and how do they relate?
- What is the file/directory structure and where do important things live?
- What commands, models, or APIs are available?
- What conventions does this project follow?
- What are the dependencies?
- What is the current state of development (what's done, what's in progress)?

### Adapt sections to the project type

**For a Ruby gem:**
- Core architecture (modules, classes, their relationships)
- Public API surface
- File layout conventions
- Backend/storage patterns
- Test structure

**For a CLI tool:**
- Available commands and subcommands
- Models/resources and their relationships
- Configuration and data paths
- How the CLI boots and discovers data

**For a web application:**
- Routes and controllers
- Models and database schema
- View/template structure
- Key services or background jobs

**For any other project type:**
- Use your judgment — what would a developer need to know to start working?

## Step 3: Write the File

```markdown
---
last_refreshed_at: "{current ISO 8601 timestamp}"
bootstrapped: true
---

# Project Context — {project name}

{synthesized content organized by topic}
```

The `bootstrapped: true` flag indicates this was generated from codebase analysis rather than from accumulated log Context Updates. Future `/project:summarize` runs will evolve the document from logs.

## Step 4: Verify

1. Confirm `chorus/project.md` was written
2. Report a brief summary of what was captured:

```
Bootstrapped chorus/project.md for {project name}

Sections:
  - Architecture (5 models, 3 backends)
  - CLI Commands (12 commands across 6 resources)
  - File Structure
  - Conventions
  - Dependencies (3 runtime, 2 dev)
  - Development Status (3 units, 2 complete)

The file is ready. Future updates via /project:summarize.
```

## Step 5: Remind about CLAUDE.md

Check if `CLAUDE.md` already references `chorus/project.md`. If not, suggest adding:

```markdown
## Project Context
For current project state derived from plan execution, see `chorus/project.md`.
```

## Rules

- **Be concise.** This is a reference document, not documentation. Short paragraphs, factual statements.
- **Organize by topic, not by file.** Group related information logically.
- **Focus on architecture, not implementation.** "Project uses FlatRecord with YAML backend for persistence" — not "line 47 of store.rb calls YAML.safe_load."
- **Include current state.** What units exist, which are complete, what's in progress.
- **Omit ephemeral data.** Test counts, specific timestamps, git history.
- **Do NOT duplicate CLAUDE.md.** The project.md complements CLAUDE.md — it captures the evolving state, while CLAUDE.md captures stable conventions and preferences. If CLAUDE.md already describes something well, reference it rather than repeating it.

## Safety

- **Never overwrite an existing `chorus/project.md`** — if it exists, abort with: "chorus/project.md already exists. Use `/project:summarize` to update it."
- **Never modify CLAUDE.md** — only suggest the addition.

## Examples

```
/project:bootstrap              # Generate chorus/project.md from current codebase
```

No arguments. Operates on the current project (determined by PWD).
