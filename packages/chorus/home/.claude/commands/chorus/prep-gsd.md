---
description: "Generate GSD-compatible PROJECT.md from epic and linked stories/tasks."
allowed-tools: Read, Write, Glob, Grep
---

# /chorus:prep-gsd

Transform Obsidian-based epic/story/task hierarchy into GSD (Get Shit Done) format for implementation.

## Usage

```
/chorus:prep-gsd [OPTIONS] <EPIC>
```

### Arguments

- `EPIC` - Required. Epic identifier - can be:
  - Filename: `package-registry.md`
  - Wiki-link style: `[[package-registry]]`
  - Title search: `"Package Registry"`
  - Path: `product/ppm/epics/package-registry.md`

### Options

- `--output <dir>` - Output directory for GSD files. Default: `.planning/`
- `--stories <list>` - Comma-separated list of specific stories to include. Default: all linked stories.
- `--milestone <name>` - Set milestone name in GSD output.
- `--dry-run` - Preview output without writing files.

## Behavior

### 1. Locate Epic

Find the epic file by searching:
1. Exact path match
2. Filename match in `**/epics/`
3. Title property match across all files with `type: epic`

### 2. Gather Linked Content

From the epic, collect:
- All stories linked via backlinks or explicit `stories:` frontmatter
- All tasks linked from gathered stories
- Questions and decisions related to the epic

### 3. Generate GSD Structure

Create `.planning/` directory with:

**PROJECT.md** - GSD project definition:
```markdown
# Project: Package Registry

## Vision
[Extracted from epic overview/description]

## Core Features
[List of story titles with brief descriptions]

## Technical Constraints
[Extracted from decisions and existing code context]

## Out of Scope (v1)
[Items marked as parked or low priority]

## Open Questions
[Unresolved questions linked to this epic]
```

**ROADMAP.md** - Phased implementation plan:
```markdown
# Roadmap: Package Registry

## Phase 1: Foundation
- [ ] Story: Registry YAML format
- [ ] Story: PPM show command

## Phase 2: Integration  
- [ ] Story: Dependency tracking
- [ ] Story: Install status display

## Phase 3: Polish
- [ ] Story: Documentation
- [ ] Story: Error handling
```

**STATE.md** - Current progress tracking:
```markdown
# State: Package Registry

## Current Phase
Phase 1: Foundation

## Completed
- (none yet)

## In Progress
- (none yet)

## Blocked
- (none yet)

## Decisions Made
- Using YAML for registry format (see [[registry-format-decision]])

## Next Actions
1. Start with /gsd:plan-phase 1
```

### 4. Story → Task Mapping

For each story, generate task structure compatible with GSD's atomic task model:

```markdown
## Story: PPM Show Command

### Tasks
1. Implement tree output for package display
2. Parse registry file for install status
3. Format output with colors for status

### Acceptance Criteria
- [ ] `ppm show [PKG]` displays package tree
- [ ] Installed packages shown in green
- [ ] Missing packages shown in red

### Source
- Epic: [[package-registry]]
- Story: [[ppm-show-command]]
```

## Output Format

### Dry Run

```
📋 GSD Prep Preview: Package Registry

Epic: product/ppm/epics/package-registry.md

Linked Stories (4):
  ✓ ppm-show-command (3 tasks)
  ✓ registry-yaml-format (2 tasks)  
  ✓ dependency-tracking (4 tasks)
  ○ documentation (not started)

Total Tasks: 9

Would generate:
  .planning/PROJECT.md
  .planning/ROADMAP.md
  .planning/STATE.md

Run without --dry-run to create files.
```

### Apply

```
✅ GSD files generated

Created:
  → .planning/PROJECT.md (2.3kb)
  → .planning/ROADMAP.md (1.1kb)
  → .planning/STATE.md (0.8kb)

Next steps:
  1. Review generated files in .planning/
  2. Run /gsd:plan-phase 1 to create task plans
  3. Run /gsd:execute-plan to implement

Epic: [[package-registry]]
Stories: 4 | Tasks: 9 | Questions: 2
```

## Integration with GSD

After running `/chorus:prep-gsd`, the GSD workflow takes over:

```bash
# GSD commands work on .planning/ directory
/gsd:plan-phase 1      # Creates atomic task plans
/gsd:execute-plan      # Subagent implements tasks
/gsd:progress          # Check status
```

### Bidirectional Sync

When GSD completes tasks:
1. `/chorus:sync-gsd` can update Obsidian note statuses
2. Story/task frontmatter `status` updated to `done`
3. Epic progress reflected in Bases views

## Examples

### Prep from epic title
```
/chorus:prep-gsd "Package Registry"
```

### Prep specific stories only
```
/chorus:prep-gsd [[package-registry]] --stories ppm-show-command,registry-yaml
```

### Preview without writing
```
/chorus:prep-gsd package-registry.md --dry-run
```

### Custom output location
```
/chorus:prep-gsd [[package-registry]] --output .planning/ppm-registry/
```

### Set milestone
```
/chorus:prep-gsd [[package-registry]] --milestone "v1.0"
```

## Notes

- GSD expects specific file structure in `.planning/` - this command ensures compatibility.
- Stories without tasks are flagged - consider breaking them down first.
- Large epics (>10 stories, >30 tasks) trigger a warning - consider splitting into milestones.
- Questions and blockers are surfaced prominently in STATE.md.
- Run `/gsd:help` after prep to see available GSD commands.
