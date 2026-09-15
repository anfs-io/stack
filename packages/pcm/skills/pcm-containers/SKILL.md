---
name: pcm-containers
description: Create or edit pcm (Personal Container Manager) container definitions — the compose.yml, .env.schema, optional provision hook and README in ~/.config/pcm/containers/<name>/. Use when the user wants to add a new container/service to pcm, wire one service to another (x-pcm.depends_on, e.g. "give it a postgres database"), write or fix an .env.schema, or make `pcm validate` pass.
---

# pcm container definitions

pcm runs podman compose projects on a dev machine. Each **container definition** is one
directory; pcm's CLI calls it a *service* (`pcm up <service>`). One definition can hold
several compose services (glitchtip runs `web` and `valkey`).

## Where definitions live

- Runtime: `$PCM_CONTAINERS_HOME/<name>/` = `~/.config/pcm/containers/<name>/`
- Source of truth: `~/.local/share/ppm/pdt/packages/pcm/home/.config/pcm/containers/<name>/`.
  Files there are stowed into `~/.config` by ppm. Create new definitions in the package, then
  run `ppm install pcm` so the new directory is linked. Commit them in the pdt repo.
- Data: `$PCM_VOLUMES_HOME/<name>/` = `~/.local/share/pcm/volumes/<name>/`
- Shared settings: `~/.config/pcm/registry.yml` (`shared_network`, `network_attached_services`)

Before writing a new one, read an existing definition as a model:
`postgres` (a dependency with a provision hook), `glitchtip` (depends on postgres, several
compose services), `dockge` (extra allowed mount).

## Files

| File | Required | Purpose |
|------|----------|---------|
| `compose.yml` | yes | The compose project, plus the `x-pcm` block |
| `.env.schema` | if `compose.yml` uses any `${VAR}` | Declares every variable, with type and default |
| `provision` | no, executable | Hook other definitions call when they depend on this one |
| `README.md` | recommended | What it is, how to start it, anything non-obvious |

Never ship a `.env`: the user stows their own next to the schema to override defaults.

## compose.yml

```yaml
# <Name> — one line on what it is (link).
#
# pcm service: `pcm up <name>`. Every variable, with its default, lives in .env.schema.
name: <name>                       # compose project name; defaults to the dir name

x-pcm:                             # optional
  depends_on:                      # other pcm definitions this one needs
    postgres:                      # map form: settings passed to postgres's provision hook
      database: <name>
  # depends_on: [postgres]         # list form: no settings
  allow_mounts:                    # extra host paths this definition may mount
    - ${PCM_PODMAN_SOCKET}

services:
  app:
    image: ${APP_IMAGE}:${APP_TAG}   # fully qualified image (docker.io/...), set in the schema
    restart: unless-stopped
    ports:
      - "${APP_PORT}:8080"           # every host port comes from the schema
    environment:
      DATABASE_URL: ${PCM_POSTGRES_URL}
    volumes:
      - ${PCM_VOLUMES_HOME}/<name>/data:/data
      - ./config.toml:/etc/app/config.toml:ro
    healthcheck:                     # add one if anything depends on this definition
      test: ["CMD-SHELL", "..."]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Volume rules (`pcm validate` errors)

- Bind mounts must be under `${PCM_VOLUMES_HOME}/<name>/`. pcm creates missing directories there on `up`.
- Read-only mounts (`:ro`) may come from the definition directory (`./file`).
- No named volumes, no anonymous volumes (a bare `/path`), no top-level `volumes:`, no `..`.
- Any other host path must be listed in `x-pcm.allow_mounts`. On Linux it must also exist.
- `tmpfs` mounts are fine.

Also:

- **Image VOLUMEs:** if the image declares a `VOLUME`, mount something at that path, or podman
  creates a new anonymous volume on every run (a warning). Postgres mounts
  `${PCM_VOLUMES_HOME}/postgres` at `/var/lib/postgresql/data` and sets `PGDATA` to a
  subdirectory.
- **Non-root images:** add `:U` so rootless podman chowns the host directory
  (`.../uploads:/code/uploads:U`).

### Dependencies and networking

- **Startup:** for each `x-pcm.depends_on` entry, `pcm up` does four things in order:
  1. starts the dependency if it isn't running
  2. waits until its healthchecks pass (`PCM_HEALTH_TIMEOUT`, default 120s)
  3. runs its `provision` hook with the map settings as `key=value` args
  4. exports each `KEY=VALUE` the hook prints as `PCM_<DEP>_<KEY>` (dep upper-cased, `-`→`_`)
- **Existing values:** a value already in the environment wins over one the hook prints.
- **Shared network:** definitions with dependencies, or listed in `registry.yml`
  `network_attached_services`, join the shared network (`dev-net`). They also keep their project's
  default network. Reach a dependency by the container name it provisions (e.g. `HOST`).
- **Stopping:** `pcm down` refuses while running definitions depend on the target, unless `--force`
  is passed.
- **Rules:** dependencies must name existing definitions, with no cycles.

## .env.schema

This is a [varlock](https://varlock.dev) schema. pcm runs compose and provision hooks through
`varlock run` from the definition directory. Values resolve as environment > `.env` > schema
defaults, and invalid values stop the command.

```sh
# <Name> config schema — canonical source of truth for every tunable.
#
# Validate: varlock load --path .
#
# @defaultSensitive=false @defaultRequired=infer
# ---

## Image — fully qualified for Podman (no docker.io assumption).
# @type=string
APP_IMAGE=docker.io/example/app
# @type=string
APP_TAG=1

## Core config
# What it does. The dev default is INSECURE — set a real one for anything shared.
# Generate: openssl rand -hex 32
# @required @sensitive @type=string
APP_SECRET_KEY=dev-insecure-change-me
# Host port.
# @type=port
APP_PORT=8080

## Injected by pcm — do not set
# Connection URL for the shared pcm postgres (x-pcm.depends_on in compose.yml).
# Optional because pcm only provisions it on `up`; `down`, `logs` etc. run without it.
# @optional @sensitive @type=url
PCM_POSTGRES_URL=
# Root of pcm service volumes.
# @required @type=string
PCM_VOLUMES_HOME=
```

- **Layout:** each variable gets a comment line, then a `# @...` decorator line, then `NAME=default`.
  Group variables under `## Section` headings.
- **Types used so far:** `string`, `port`, `url`, `ip`, `enum(True, False)`. Add `@required`,
  `@optional` and `@sensitive` as needed. Don't use `@type=email` for a default with no TLD, because
  varlock rejects it.
- **Declare everything:** every `${VAR}` in `compose.yml` must be declared, including pcm's own.
- **Defaults:** they should boot the service untouched on a dev machine. Mark insecure ones.
- **Variables pcm injects:** list them last, empty, under "Injected by pcm — do not set":
  - `PCM_VOLUMES_HOME`: always, `@required`.
  - `PCM_PODMAN_SOCKET`: the podman API socket, set only when `compose.yml` references it.
    `@required`, and list it in `allow_mounts`.
  - `PCM_<DEP>_<KEY>`: from dependency provisioning, `@optional`.

## provision hook

This is only needed when other definitions depend on this one and need something set up or
passed back, like a database and its connection URL. Model it on `postgres/provision`.

- **How it's run:** `#!/usr/bin/env bash`, `set -euo pipefail`, executable (`chmod +x`). pcm runs it
  from this definition's directory under varlock, so this definition's schema variables are set.
- **Inputs:** `key=value` args from the dependent's `depends_on` map. Reject unknown keys and
  validate values. Extra env:
  - `PCM_SERVICE`: this definition
  - `PCM_PROJECT`: its compose project, used to find containers with
    `podman ps --filter label=com.docker.compose.project=$PCM_PROJECT`
  - `PCM_DEPENDENT`: the definition asking
- **Behavior:** it must be idempotent, because it runs on every `pcm up` of a dependent.
- **Output:** `KEY=VALUE` lines on stdout (upper-case keys) and nothing else. Send logs and
  progress to stderr. Document the keys in the header comment.

## Secrets

If `fnox` is installed and a `fnox.toml` is in the definition directory or
`$PCM_CONTAINERS_HOME`, pcm wraps each call in `fnox exec` so secrets are in the environment
before varlock resolves.

## Workflow

1. Create `<name>/` with `compose.yml` and `.env.schema`, plus `provision` and `README.md` if needed.
2. `cd <name> && varlock load --path .` to check the schema on its own.
3. `pcm validate <name>`. Fix every error. Treat warnings (image VOLUMEs, host-port clashes with
   other definitions) as bugs unless there's a reason.
4. `ppm install pcm` if the definition was created in the package, then `pcm up <name>`.
5. Check it: `pcm ps`, `podman compose --pcm logs -f <name>`, then `pcm down <name>`.

Only report the definition as working after `pcm validate` passes and `pcm up` starts it
healthy. If you couldn't run them, say so.
