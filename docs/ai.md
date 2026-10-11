
# AI - anfs packages for AI agents, generic agent skills for all agent harnesses and local model runners

The `ai` category of [stack](../README.md), an anfs default source, so a fresh install already
has it: the packages that declare `categories: [ai]`. Their skills live in stack's `skills/` (psm).
psm itself is part of anfs.

## Usage

```bash
ppm list @ai
ppm install [PACKAGE]
```

## Common Packages

```bash
ppm install claude omlx pi
```

### Shortcut to install all packages

```bash
ppm install @ai
```


### Claude Code

Installs the latest claude code via mise. claude code depends on Node

### oMLX

Installs the latest oMLX via brew so you can run AI models locally!

### Pi Coding Agent

Installs the latest Pi coding agent via mise
