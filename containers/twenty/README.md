# Twenty

Open-source CRM (<https://twenty.com>). The stack is a Twenty server and a worker
(same image). It uses the shared pcm postgres, and the shared pcm valkey for BullMQ
queues and cache, both declared in `x-pcm.depends_on`.

## Run

```sh
pcm up twenty                         # starts postgres + valkey if needed, creates the db
pcm down twenty                       # stop (postgres and valkey keep running)
podman compose --pcm logs -f twenty
```

Web UI: <http://localhost:8020>. Sign up to create the first workspace.

The first boot is slow: the server's entrypoint runs `database:init` and then
`upgrade` before it listens, and the healthcheck allows 3 minutes for that. The
worker waits until the server is healthy.

## Things to know

- **`TWENTY_SERVER_URL` must match the URL in your browser exactly** (scheme,
  host, port). Otherwise login and CORS break. Update it whenever you change
  `TWENTY_PORT` or put Twenty behind a hostname or proxy.
- **Upgrades:** `TWENTY_TAG` is pinned. Each start runs `upgrade` against the
  database, and Twenty doesn't support skipping versions, so move up one
  release at a time. Back up first with `pg_dump twenty`.
- **Database:** Twenty creates `core`, `metadata` and one schema per workspace in
  the `twenty` database, as the shared postgres superuser. Upstream tests against
  postgres 16, while pcm's postgres is 17.
- **Memory:** server and worker together use about 1–1.5 GB. On the default
  podman VM (4 GB), raise it if you run several stacks:
  `podman machine stop && podman machine set --memory 8192 && podman machine start`.
- **Files** (attachments, avatars) are stored locally in
  `~/.local/share/pcm/volumes/twenty/storage`.

## Configuration

All tunables and their defaults live in [`.env.schema`](./.env.schema). To
override, add a `.env` next to it; none is shipped. Real secrets belong in fnox.

> **Secrets:** `TWENTY_APP_SECRET` and `TWENTY_ENCRYPTION_KEY` ship with
> insecure dev defaults. Set real ones (`openssl rand -base64 32`) *before first
> boot* for anything shared. Changing `TWENTY_ENCRYPTION_KEY` later makes stored
> credentials (connected accounts, API keys) unreadable.
