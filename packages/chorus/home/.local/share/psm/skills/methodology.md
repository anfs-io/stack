# Development Methodology

## Maturity Units

Most (not all) projects follow a three-tier maturity model, where each tier is represented as a **unit** in the Chorus workflow system:

| Tier | Objective | Question It Answers |
|------|-----------|-------------------|
| Foundation | It works | Does the core functionality work correctly? |
| Production | You can trust it | Does it fail gracefully, validate inputs, handle edge cases? |
| Platform | You can build on it | Can others extend it, integrate it, build on top of it? |

Tiers are always sequential: foundation → production → platform.

## Plans

Each unit is decomposed into numbered plans (01-slug, 02-slug, etc.) that are sequential within the unit. Each plan is a self-contained unit of work with:

- **Context section** — files to read before starting
- **Implementation spec** — what to build and how
- **Test spec** — what tests to write
- **Verification** — concrete pass/fail checks

## Document Structure

Plans live inside the project's `chorus/units/` directory, using Chorus's nested layout:

```
chorus/units/
  foundation.md                      # unit metadata (YAML frontmatter + narrative)
  foundation/
    01-{slug}/
      plan.md                        # plan spec (YAML frontmatter + markdown body)
      log.md                         # execution log (created by CC on completion)
    02-{slug}/
      plan.md
      log.md
    ...
  production.md
  production/
    01-{slug}/
      plan.md
    ...
  platform.md
  platform/
    ...
```

### Unit file format (`{unit}.md`)

```markdown
---
objective: It works
status: in_progress
---

Foundation tier. Brief narrative of what this unit covers.

## Completion Criteria

- Criterion one
- Criterion two
```

### Plan file format (`plan.md`)

```markdown
---
---

# Plan 01 — Descriptive Name

## Context — read these files first

- `lib/path/to/file.rb` — what to look for
- `spec/path/to/spec.rb` — existing tests

## Overview

What this plan does and why.

## Implementation

Step-by-step implementation spec.

## Test Spec

What tests to write.

## Verification

Concrete pass/fail checks.
```

### Log file format (`log.md`)

Created by Claude Code on plan completion. Presence of `log.md` indicates the plan is complete — no separate state tracking file needed.

```markdown
---
status: complete
summary: Brief description of what was done
started_at: "2026-02-01T10:00:00+08:00"
completed_at: "2026-02-01T10:30:00+08:00"
---

Narrative of execution: deviations, decisions, notable details.
```

## Workflow: Claude Desktop → Claude Code

1. **Design** (Claude Desktop): Discuss the unit, work through features, make architectural decisions
2. **Document** (Claude Desktop): Write the unit `.md` file and plan files to `chorus/units/{unit}/`
3. **Build** (Claude Code): Read plans, implement, test, write log on completion
4. **Feedback** (manual): Test in console, discuss issues in next session
5. **Iterate** (Claude Code): Pick up next plan, or revise current one based on feedback

## Output Conventions

When designing a unit with Claude Desktop:

- Write the unit `.md` file first (objective, status, completion criteria)
- Then write each plan's `plan.md` with full implementation spec
- Plans should reference existing code by file path so Claude Code can read them
- Include test specs in every plan — tests are deliverables, not optional
- Each plan should be independently executable by Claude Code in a single session

## Context Window Management

Plans are natural compaction boundaries. After completing each plan, the full state is captured on disk (code, specs, log.md). Nothing in the conversation history is needed that isn't already in files.

**After completing each plan, Claude Code should:**

1. Write `log.md` alongside the completed `plan.md`
2. Run all specs to confirm green
3. Print this exact message for the user to copy-paste:

```
/compact Summarize: which plan was just completed, what files were created or modified, any deviations from the plan or decisions made during implementation, and what the next plan is. Drop all source code contents, test output, and intermediate debugging steps.
```

Note: Built-in commands like `/compact` cannot be invoked programmatically from skills or custom commands. The user must run it manually.

**Why this matters:**
- The context window charges for all accumulated tokens on every turn
- As the window fills, the model's attention degrades ("lost in the middle" problem)
- Compaction between plans loses nothing because plans are self-contained — the next plan's Context section lists exactly which files to read
- `/compact` keeps a summary of what happened; `/clear` wipes everything (prefer `/compact`)

**Plan sizing guideline:** If a plan requires reading so many source files that the context window fills up during execution (before implementation is complete), the plan is too large. Split it. A good plan should leave room for: CLAUDE.md + methodology + plan file + source files listed in Context + implementation + test output.

## Handoff Checklist

Before handing off to Claude Code, verify:

- [ ] `CLAUDE.md` exists at the project root with project context
- [ ] `chorus/units/{unit}.md` exists with unit overview and completion criteria
- [ ] All plan directories created with `plan.md` files
- [ ] Plan dependencies are documented (which plans depend on which)
- [ ] Fixture/test data is defined
