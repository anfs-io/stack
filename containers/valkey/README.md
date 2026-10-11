# Valkey

Shared, Redis-compatible key-value store for pcm services (<https://valkey.io>).
It works like the shared postgres: one instance, and each dependent gets its own
slice.

## Run

```sh
pcm up valkey          # or let a dependent start it
pcm down valkey        # refuses while dependents are running (--force overrides)
podman exec -it valkey_valkey_1 valkey-cli
```

## Dependents

Declare it in `compose.yml` and use the injected URL:

```yaml
x-pcm:
  depends_on:
    valkey: {}

services:
  app:
    environment:
      REDIS_URL: ${PCM_VALKEY_URL}   # redis://valkey_valkey_1:6379/<n>
```

Add `PCM_VALKEY_URL` to the dependent's `.env.schema` as `@optional @type=url`,
under "Injected by pcm". `PCM_VALKEY_HOST`, `_PORT` and `_DATABASE` are also
available.

`provision` gives each dependent its own logical database the first time it
starts, and it keeps that number across restarts. The allocations are stored in db 0:

```sh
podman exec valkey_valkey_1 valkey-cli -n 0 HGETALL pcm:databases
```

## Things to know

- **Server-wide settings apply to everyone.** `maxmemory-policy noeviction` is
  set because job queues (BullMQ, celery) lose jobs under eviction. No memory
  limit is set, so caches grow until the app expires them.
- **Logical databases are not isolation.** Any client can `SELECT` another db,
  and `FLUSHALL` wipes every app. That's fine for dev. For real isolation, switch
  provision to per-dependent ACL users.
- **Capacity:** `VALKEY_DATABASES` (default 64) minus db 0.
- **Persistence:** AOF on, in `~/.local/share/pcm/volumes/valkey`.
- **Reset one app's keys:** `valkey-cli -n <db> FLUSHDB`. Leave its entry in
  `pcm:databases` so it keeps the same number.
