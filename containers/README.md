# pcm-containers

Container definitions for [pcm](https://github.com/anfs-io/system/tree/main/packages/pcm), the
Personal Container Manager, in [stack](../README.md), an anfs default source. `pcm up postgres`
resolves to `stack/postgres` unless a higher-priority source defines `postgres`.

## Layout

```
containers/<name>/
  compose.yml     # the service; x-pcm: keys for dependencies and allowed mounts
  .env.schema     # every variable compose.yml uses, with types and defaults (varlock)
  provision       # optional: dependency hook (see postgres)
  README.md
```

Any git repo with this layout is a pcm source: `pcm src add <git-url> [alias]`.

## Local overrides

Don't put a `.env` in the clone (it is ignored, and would hide from `pcm src list`). Use
`~/.config/pcm/env/<name>.env` instead: pcm exports it before varlock resolves the schema.

## Validate

```sh
pcm validate            # every service pcm resolves
pcm validate stack/n8n  # one definition from this repo
```
