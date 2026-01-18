---
description: "Add or update frontmatter on existing markdown files for Obsidian Bases compatibility."
allowed-tools: Read, Write, Edit, Glob, Grep
---

# /chorus:enrich

Add structured frontmatter to existing markdown files, making them queryable by Obsidian Bases without restructuring content.

## Usage

```
/chorus:enrich [OPTIONS] <PATH>
```

### Arguments

- `PATH` - Required. File or directory to enrich.

### Options

- `--apply` - Write changes to files. Without this flag, shows preview only.
- `--atomize` - Break file into individual atomic notes (one per item). More destructive - always previews first.
- `--type <type>` - Override detected type (epic, story, backlog, overview, etc.)
- `--domain <domain>` - Override detected domain.
- `--recursive` - Process all .md files in directory tree.

## Behavior

### Mode 1: Summary Frontmatter (default)

Analyzes file content and adds summary frontmatter without changing body:

```yaml
---
title: "PPM Backlog"
type: backlog
domain:
  - ppm
contains:
  features: 12
  bugs: 3
  questions: 2
  decisions: 5
  tasks: 8
status_summary:
  todo: 15
  done: 5
  in_progress: 3
keywords:
  - stow
  - mise
  - registry
  - dependency
last_enriched: 2025-01-15
---
```

This makes the file visible in Bases views as a document-level entry.

### Mode 2: Atomize (with --atomize)

Breaks file into individual atomic notes:

1. Parse file identifying discrete items
2. Generate individual notes in `_preview/`
3. Create index file linking to all extracted items
4. Original file becomes lightweight index after apply

**Preview output:**
```
_preview/
├── stories/
│   ├── ppm-show-command.md
│   ├── registry-yaml.md
│   └── dependency-refactor.md
├── bugs/
│   └── linux-install-git.md
└── _original-as-index.md    # What original file becomes
```

### Frontmatter Detection Rules

**Type detection:**
- Filename contains "backlog" → `type: backlog`
- Filename contains "overview" → `type: overview`
- Content has "# Why" + "# Acceptance Criteria" → `type: epic`
- Content is primarily bullet lists → `type: backlog`
- Single coherent topic → `type: story` or `type: decision`

**Domain detection:**
- Parent directory name if matches schema domain
- Keywords in content matching schema domains
- Explicit header references (## PPM Features)

**Content analysis:**
- Count `- [ ]` as todo items
- Count `- [x]` as done items
- Count `- [ ]` with `?` as questions
- Count headers to estimate structure depth
- Extract keywords from headers and emphasized text

## Output Format

### Preview Mode (default)

```
📝 Enrich Preview: product/ppm/ppm backlog.md

Detected:
  Type: backlog
  Domain: ppm
  
Content Analysis:
  Features: 12
  Bugs: 3
  Questions: 2
  Tasks (todo): 15
  Tasks (done): 5
  
Keywords: stow, mise, registry, dependency, force, remove

Proposed frontmatter:
---
title: "PPM Backlog"
type: backlog
domain:
  - ppm
contains:
  features: 12
  bugs: 3
  questions: 2
status_summary:
  todo: 15
  done: 5
last_enriched: 2025-01-15
---

Run `/chorus:enrich --apply product/ppm/ppm\ backlog.md` to write.
```

### Atomize Preview

```
📝 Atomize Preview: product/ppm/ppm backlog.md

Would extract 23 items:
  📖 Stories: 12
  🐛 Bugs: 3
  ❓ Questions: 2
  ✅ Tasks: 6

Preview files in: _preview/

Original file would become index with links to:
  - [[ppm-show-command]]
  - [[registry-yaml]]
  - [[dependency-refactor]]
  ... (20 more)

Run `/chorus:enrich --atomize --apply ...` to commit.
```

## Examples

### Preview enrichment
```
/chorus:enrich product/ppm/ppm\ backlog.md
```

### Apply frontmatter to file
```
/chorus:enrich --apply product/ppm/ppm\ backlog.md
```

### Enrich all files in directory
```
/chorus:enrich --recursive --apply product/
```

### Atomize a backlog file
```
/chorus:enrich --atomize product/ppm/ppm\ backlog.md
```

### Force type override
```
/chorus:enrich --type epic --apply product/ppm/package-registry.md
```

## Integration with Obsidian Bases

After enrichment, create `.base` files to query enriched content:

**backlogs.base** - All backlog files across domains:
```yaml
filter:
  - property: type
    op: eq
    value: backlog
columns:
  - title
  - domain
  - contains.features
  - contains.bugs
  - status_summary.todo
```

**by-domain.base** - Items in specific domain:
```yaml
filter:
  - property: domain
    op: contains
    value: ppm
sort:
  - property: status_summary.todo
    order: desc
```

## Notes

- Enrichment is idempotent - running twice updates rather than duplicates frontmatter.
- Existing frontmatter is preserved and merged with detected values.
- User-set values (priority, effort) are never overwritten by detection.
- The `last_enriched` timestamp tracks when analysis was last run.
- Atomize always previews first regardless of --apply flag on first run.
