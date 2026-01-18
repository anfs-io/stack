---
description: "Parse inbox files and generate atomic notes with frontmatter. Dry-run by default."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /chorus:triage

Parse brain dump content from inbox and generate atomic notes with structured frontmatter compatible with Obsidian Bases.

## Usage

```
/chorus:triage [OPTIONS] [PATH]
```

### Arguments

- `PATH` - Optional. Specific file or directory to process. Defaults to `inbox/` directory.

### Options

- `--apply` - Move previewed files from `_preview/` to their destination. Without this flag, changes are staged for review only.
- `--schema` - Display current schema and any newly discovered domains.
- `--epic <name>` - Associate all extracted items with an existing or new epic.
- `--domain <domain>` - Override domain detection, assign all items to specified domain.

## Behavior

### 1. Locate the Base

Determine the base root by searching upward for `.schema.yml` or `.obsidian/` directory from the current working directory. If not found, prompt user for base path.

### 2. Load Schema

Read `.schema.yml` from base root. If not present, create default schema and notify user.

### 3. Parse Input Files

For each file in scope:

1. **Read content** preserving original structure
2. **Identify sections** by headers (##, ###) - these become context tags
3. **Extract items** - lines starting with `- [ ]`, `- [x]`, or `- ` followed by actionable content
4. **Classify each item**:
   - Contains `?` or starts with "ask", "should we", "need to figure" → `question`
   - Contains "bug", "fix", "broken", "doesn't work" → `bug`
   - Contains "idea", "maybe", "could", "might" → `idea`
   - Contains "decided", "choosing", "will use" → `decision`
   - Default → `story`
5. **Detect domains** from:
   - Parent header context (## ppm → domain: ppm)
   - Content keywords matching schema domains
   - File location (product/ppm/* → domain: ppm)
6. **Detect hierarchy**:
   - Items with sub-items become `story` with child `task` notes
   - Standalone complex items (multiple sentences, acceptance criteria) → `epic`

### 4. Generate Preview

Create atomic notes in `_preview/` directory:

```
_preview/
├── epics/
│   └── package-registry.md
├── stories/
│   └── ppm-show-command.md
├── tasks/
│   └── implement-tree-output.md
├── questions/
│   └── registry-scope.md
└── _manifest.md          # Summary of all generated files
```

Each file includes:

```yaml
---
title: "Descriptive title extracted from content"
type: story
status: inbox
epic: ""
domain:
  - ppm
priority: null
effort: null
source: "inbox.md"
source_header: "## ppm"
created: 2025-01-15
triaged: 2025-01-15
---

Original content here, cleaned up but preserving intent.

## Source Context

Extracted from [[inbox]] under section "## ppm"
```

### 5. Generate Manifest

Create `_preview/_manifest.md` summarizing:

- Total items extracted
- Breakdown by type (epics, stories, tasks, questions, etc.)
- Breakdown by domain
- Any schema additions (new domains discovered)
- Any warnings (ambiguous items, potential duplicates)

### 6. Apply Changes (with --apply)

When `--apply` is passed:

1. Verify `_preview/` exists and has content
2. Move files to destination:
   - `_preview/epics/*` → `product/<domain>/epics/`
   - `_preview/stories/*` → `product/<domain>/stories/`
   - `_preview/tasks/*` → `product/<domain>/tasks/`
   - `_preview/questions/*` → `product/<domain>/questions/`
3. Update `.schema.yml` with any new domains
4. Clear `_preview/` directory
5. Optionally: Comment out or mark processed items in source file

## Output Format

### Preview Mode (default)

```
📥 Triage Preview for: inbox.md

Extracted 12 items:
  📦 Epics: 1
  📖 Stories: 6
  ✅ Tasks: 3
  ❓ Questions: 2

By Domain:
  ppm: 7
  chorus: 4
  infra: 1

New domains discovered: (none)

Preview files written to: _preview/
Review with Obsidian or run `/chorus:triage --apply` to commit.
```

### Apply Mode

```
✅ Applied triage results

Moved 12 files:
  → product/ppm/stories/ppm-show-command.md
  → product/ppm/tasks/implement-tree-output.md
  ... 

Source file: inbox.md
  (Original preserved - consider archiving processed items)
```

## Examples

### Basic triage of inbox
```
/chorus:triage
```

### Triage specific file
```
/chorus:triage product/ppm/ppm\ backlog.md
```

### Apply after review
```
/chorus:triage --apply
```

### Associate with epic during triage
```
/chorus:triage --epic "Package Registry" inbox.md
```

### Check schema and discovered domains
```
/chorus:triage --schema
```

## Notes

- Always preview first. The `--apply` flag is intentionally separate.
- Items are deduplicated by content similarity - exact matches are flagged.
- Backlinks are automatically created between parent/child items.
- The `source` and `source_header` fields enable tracing back to origin.
- Run from base root or any subdirectory - command finds base automatically.
