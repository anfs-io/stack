---
description: "Execute plans from chorus/units/{unit}/. Completion tracked by log.md presence. Auto-detects current unit or accepts explicit args."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, TodoRead, TodoWrite
---

# /project:build [$UNIT] [$PLAN]

Execute plans from a unit of work, with automatic progress tracking.

## Directory Structure

Plans live in the project's `chorus/units/` directory:

```
chorus/
  units/
    {unit}.md                           # Unit overview (objective, status, plan listing)
    {unit}/
      {NN}-{slug}/
        plan.md                         # The plan specification
        log.md                          # Execution log (presence = complete)
```

- **Unit overview**: `chorus/units/{unit}.md` — contains YAML frontmatter with `objective` and `status`, plus a markdown description and plan listing
- **Plan file**: `chorus/units/{unit}/{NN}-{slug}/plan.md` — the implementation specification
- **Log file**: `chorus/units/{unit}/{NN}-{slug}/log.md` — written by Claude Code after successful execution

## Completion Tracking

There is no centralized state file. Completion is inferred from the filesystem:

- **Plan is complete** if `log.md` exists alongside `plan.md`
- **Plan is pending** if only `plan.md` exists (no `log.md`)
- **Unit is complete** if every plan directory in the unit has a `log.md`

## Unit Discovery

Units are not fixed names. They are whatever directories exist under `chorus/units/`. The unit overview `.md` file contains the status:

```yaml
---
objective: Refactor nomenclature and hierarchy
status: planned    # or: in_progress, complete
---
```

To determine execution order, read the unit overview files. A unit with `status: planned` or `status: in_progress` is eligible for execution.

## Arguments

All arguments are optional:

- No args → auto-detect the current unit (first non-complete unit) and execute all remaining plans
- `$UNIT` only → execute all incomplete plans in that unit
- `$UNIT next` → execute only the next incomplete plan, then stop
- `$UNIT {number}` → execute that specific plan regardless of completion (e.g., `hierarchy-refactor 02`)
- `$UNIT {start}-{end}` → execute a range of plans (e.g., `hierarchy-refactor 1-3`), skipping completed ones

## Auto-Detection Logic

When no `$UNIT` is provided:

1. Scan `chorus/units/*.md` for unit overview files
2. Read each unit's frontmatter `status` field
3. The current unit is the first one with `status` not equal to `complete`
4. If all units are complete, report: **"All units complete. Nothing to build."**

## Log File Format

When a plan is successfully executed, write `log.md` in the plan directory:

```markdown
---
status: complete
started_at: "2026-02-27T10:30:00+08:00"
completed_at: "2026-02-27T10:42:15+08:00"
deviations: null
summary: Renamed tier to unit across all models, commands, views, and specs
---

# Execution Log

## What Was Done

- Renamed Tier model to Unit
- Updated all foreign keys from tier_id to unit_id
- ...

## Test Results

636 examples, 0 failures

## Notes

Any observations, decisions made during implementation, or deviations from the plan.

## Context Updates

Proposed changes for the project context file (`chorus/project.md`). Write this section
as factual, concise statements about what changed architecturally. Focus on what the
next Claude session needs to know — not a changelog, but a description of current state
after this plan's changes.

Examples of good context updates:
- "Unit model replaces the former Tier model. All references updated."
- "New Area model introduced between Space and Project in the hierarchy."
- "CLI commands now use `unit list/show` instead of `tier list/show`."
- "Project discovery now checks for `.chorus.yml` file presence."

Examples of things NOT to include:
- Test counts or spec details (ephemeral)
- File-by-file change lists (that's what git is for)
- Implementation details that don't affect the next developer's understanding
```

### Log rules

- Record `started_at` (ISO 8601) when beginning a plan
- Record `completed_at` (ISO 8601) when verification passes
- Use the system clock via bash (`date -Iseconds`) to get timestamps
- `status` should be `complete` or `failed`
- `deviations` captures anything that diverged from the plan (null if none)
- `summary` is a one-line description of what was accomplished
- The markdown body provides detailed notes for future reference
- The `## Context Updates` section is **required** — this feeds into `chorus/project.md` via the `/project:summarize` command
- If a plan is re-run, overwrite the existing `log.md`

## Workflow

### 1. Load Context

1. Read `CLAUDE.md` at the project root
2. If `chorus/project.md` exists, read it for current project state
3. Determine the unit (from arg or auto-detection)
4. Read `chorus/units/{unit}.md` for unit objectives and plan listing
5. Scan `chorus/units/{unit}/` for plan directories
6. Determine completion status of each plan (log.md presence)
7. Determine which plan(s) to execute:
   - No `$PLAN` arg → all plans without `log.md`, in numeric order
   - `next` → first plan without `log.md`
   - A number → that specific plan directory (match by `{NN}-` prefix)
   - A range → plans within that range without `log.md`, in order
8. Read the target `plan.md` and any files referenced in it

### 2. Check Feedback

1. Create `docs/feedback/` and `docs/feedback/archive/` directories if they don't exist
2. Scan `docs/feedback/` for any `.md` files (ignore the `archive/` subdirectory)
3. If no files found, continue to next step
4. If files found, list them and ask: **"Found {n} feedback file(s): {filenames}. Process them before continuing?"**
5. If I say no, skip feedback and continue to next step
6. If I say yes, for each feedback file (in sorted order):
   a. Present the feedback items
   b. Implement the fixes
   c. Run the full test suite
   d. Ask: **"Feedback from {filename} addressed. Please test and confirm."**
   e. On confirmation, move the file to `docs/feedback/archive/`
7. Once all feedback is processed (or skipped), continue to next step

### 3. Sanity Check (per plan)

1. Check that prerequisite plans have `log.md` (if `depends_on` is specified in plan frontmatter)
2. Evaluate the plan for issues, gaps, or ambiguities
3. Present a brief summary:
   - What this plan builds
   - Any concerns
4. Ask: **"Ready to proceed?"**

If I say no, stop.

### 4. Implement (per plan)

1. Record `started_at` timestamp
2. Implement components in the order specified by the plan
3. After each significant component, run relevant specs
4. If specs fail, fix before moving on
5. Continue until all components are implemented

### 5. Verify (per plan)

1. Run the full test suite: `bundle exec rspec`
2. Execute any verification steps from the plan's "Verification" section
3. If all checks pass:
   - Record `completed_at` timestamp
   - Write `log.md` to the plan directory (including the `## Context Updates` section)
   - Update the unit overview `.md` frontmatter `status` to `in_progress` (or `complete` if all plans done)
   - Report: **"Plan {NN}-{slug} complete."**
4. If checks fail:
   - Report which checks failed
   - Offer to fix
   - If I decline, write `log.md` with `status: failed` and stop

### 6. Continue or Finish

- If running all plans (or a range) and current plan is complete, proceed to next plan (back to step 3)
- If running `next`, stop after the one plan
- When all targeted plans are complete, report: **"{unit} complete. All plans verified."**
- If all plans in the unit are done, update the unit overview frontmatter to `status: complete`

## Examples

```
/project:build                                # Auto-detect unit, run all remaining plans
/project:build hierarchy-refactor             # Run all incomplete plans in hierarchy-refactor
/project:build hierarchy-refactor next        # Run only the next incomplete plan
/project:build hierarchy-refactor 02          # Run plan 02 specifically
/project:build hierarchy-refactor 1-3         # Run plans 01 through 03 (skips completed)
```

## Conventions

- Unit overview: `chorus/units/{unit}.md`
- Plan directories: `chorus/units/{unit}/{NN}-{slug}/`
- Plan file: `plan.md` inside plan directory
- Log file: `log.md` inside plan directory (written by Claude Code on completion)
- Feedback: `docs/feedback/*.md` (created by you, processed by Claude Code, archived on confirmation)
- Plans are sequential within a unit — `depends_on` in frontmatter declares prerequisites
- A plan is not complete until all its verification checks AND the full test suite pass
- Log.md presence is the single source of truth for completion — no separate state file
- The `## Context Updates` section in log.md feeds into `chorus/project.md` via `/project:summarize`
