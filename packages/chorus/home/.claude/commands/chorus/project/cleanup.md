---
description: "Migrate a project's docs/ directory to the chorus/units/ hierarchy. Run from the project root."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /chorus:cleanup

Migrate this project's `docs/` tier/plan structure into the `chorus/units/` hierarchy expected by the chorus CLI.

## What You Do

You are in the root directory of a project. The project has a `docs/` directory containing tiers, plans, a `state.yml`, and a `log.yml`. Your job is to transform this into the `chorus/units/` layout.

## Step 1: Survey

Read `docs/state.yml` and `docs/log.yml` to understand all units and plans. List what you find:

```
Units found: foundation, production, extensions
Plans per unit: foundation(5), production(10), extensions(8)
```

Read each unit's `README.md` to extract the objective line (usually the first sentence after `## Objective` or in the first paragraph).

## Step 2: Determine plan locations

Plans can be in two locations:
- **Flat in unit dir:** `docs/{unit}/plan-NN-slug.md` (most projects)
- **In plans/ subdir:** `docs/{unit}/plans/plan-NN-slug.md` (some older layouts)

Check both locations and handle whichever exists.

## Step 3: Create the new hierarchy

For each unit, create:

```
chorus/units/{unit}.md                    # Unit record with frontmatter
chorus/units/{unit}/NN-slug/plan.md       # Plan record (moved + frontmatter added)
chorus/units/{unit}/NN-slug/log.md        # Log record (if state.yml says complete and log.yml has data)
```

### Unit .md files

Create `chorus/units/{unit}.md` with frontmatter derived from the README and state:

```markdown
---
objective: <extracted from README.md — the 1-2 sentence objective>
status: <"complete" if ALL plans in state.yml are complete, else "in_progress", else "pending" if none started>
---

<copy the full README.md body here as content>
```

### Plan directories

For each plan `plan-NN-slug.md`, strip the `plan-` prefix to get the directory name `NN-slug`:

- `plan-01-skeleton-config.md` → directory `01-skeleton-config/`
- `plan-08-markdown-array-frontmatter.md` → directory `08-markdown-array-frontmatter/`

Move the plan file into the directory as `plan.md`. The plan files generally have no frontmatter — that's fine, just add an empty frontmatter block if none exists:

```markdown
---
---

<original plan content>
```

If a plan file already has frontmatter, preserve it.

### Log files

For each plan that has BOTH a `complete` status in `state.yml` AND an entry in `log.yml`, create a `log.md`:

```markdown
---
status: complete
started_at: <from log.yml start_time>
completed_at: <from log.yml finish_time>
summary: <total_time from log.yml>
---

Completed in <total_time>.
```

**Handle both state.yml formats:**
- Format A (flat_record, chorus): `plan-01-xxx: complete`
- Format B (pcs): `plan-01-xxx:\n  status: complete`

If a plan is marked complete in state.yml but has no log.yml entry, still create a log.md with status complete but without timing data:

```markdown
---
status: complete
---

Completed (no timing data recorded).
```

If a plan is not complete (pending, in_progress, or missing from state.yml), do NOT create a log.md.

## Step 4: Preserve non-plan content

Some unit directories have extra subdirectories like `data/`, `logs/`, `feedback/`. Leave these in `docs/{unit}/` — don't move them.

Move `docs/backlog.md` to `chorus/backlog.md` if it exists.

Do NOT move `docs/state.yml` or `docs/log.yml` — they'll be deleted in the cleanup step.

Do NOT move `docs/feedback/` — leave it in docs.

## Step 5: Cleanup

After creating the new hierarchy:

1. Delete `docs/state.yml`
2. Delete `docs/log.yml`  
3. Delete the plan files from their old locations (the originals in `docs/{unit}/` or `docs/{unit}/plans/`)
4. Delete empty `plans/` subdirectories
5. Delete unit README.md files from the old locations (content is now in `chorus/units/{unit}.md`)
6. Do NOT delete unit directories that still have content (data/, feedback/, etc.)
7. If a `docs/{unit}/` directory is now empty, delete it
8. If `docs/` itself is now empty (or only has feedback/), leave it

## Step 6: Report

Print a summary:

```
Migration complete:

Units: 4
  chorus/units/foundation.md (complete, 5 plans, 5 logs)
  chorus/units/production.md (complete, 10 plans, 10 logs)
  chorus/units/platform.md (complete, 8 plans, 8 logs)
  chorus/units/extensions.md (complete, 8 plans, 8 logs)

Moved: docs/backlog.md → chorus/backlog.md

Cleaned up:
  Deleted docs/state.yml
  Deleted docs/log.yml
  Deleted 31 old plan files
  Deleted 4 old README.md files

Remaining in docs/:
  docs/feedback/ (preserved)
```

## Edge Cases

- **Plans with sub-identifiers** like `plan-01b-multi-arch.md` → directory `01b-multi-arch/`
- **Plans that exist in state.yml but not as files** → skip with a warning
- **Plan files that exist but aren't in state.yml** → still migrate, no log.md
- **Duplicate plan numbers across units** → each unit is independent, no conflict
- **state.yml has `depends_on` fields** → ignore, don't carry into new format
- **README.md with no clear objective** → use first paragraph as objective, or "See content" as fallback
- **Unit directory already exists at `chorus/units/`** → abort with error, don't overwrite

## Safety

- **Never overwrite existing `chorus/` directory** — if it exists, abort
- **Create everything before deleting anything** — build the new tree first, then clean up
- **Print the full plan before executing** — show what will be created and deleted, ask for confirmation
