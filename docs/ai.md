
# AI - anfs packages for AI agents, generic agent skills for all agent harnesses and local model runners

An [anfs](https://github.com/anfs-io/system) source: `packages/` (ppm) and `skills/` (psm). It is
in anfs's default `system.list`, so a fresh install already has it. psm itself is part of anfs.

## Usage

```bash
anfs src add https://github.com/anfs-io/ai ai   # only if it is not already listed
ppm list ai
ppm install [PACKAGE]
```

## Common Packages

```bash
ppm install claude omlx pi
```

### Shortcut to install all packages

```bash
ppm install ai/
```


### Claude Code

Installs the latest claude code via mise. claude code depends on Node

### oMLX

Installs the latest oMLX via brew so you can run AI models locally!

### Pi Coding Agent

Installs the latest Pi coding agent via mise
