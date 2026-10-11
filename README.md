# stack

The packages, containers and skills of [anfs](https://github.com/anfs-io/system), in one source.
It is in anfs's default `system.list` (alias `stack`), above the toolkit itself (`core`).

```
packages/<name>/     ppm
containers/<name>/   pcm
skills/<name>/       psm
```

Packages are grouped by the `categories:` they declare in their package.yml. A category is only
metadata: `ppm install git` finds `packages/git`, and your own repo's `git` package still layers
over it.

```bash
ppm list @                 # the categories
ppm list @ai               # the packages in one
ppm install @ai            # all of them (skipping what this platform can't run)
ppm install git            # one package; every layer of git in source order
pcm install postgres
```

| Category | Holds |
| --- | --- |
| [ai](docs/ai.md) | agent harnesses and local model runners; their skills are in `skills/` |
| [pde](docs/pde.md) | Personal Development Environment: shells, editor, git, languages |
| [pdt](docs/pdt.md) | Product Development Toolkit: infrastructure and product tooling |
| [utils](docs/utils.md) | networking, storage, putting an OS onto hardware |

This repo merges the former `ai`, `pde`, `pdt`, `utils` and `core-pcm` repos, with their history.
