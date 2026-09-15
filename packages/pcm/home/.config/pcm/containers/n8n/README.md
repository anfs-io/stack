# n8n

Workflow automation: connect APIs, databases and services with a visual editor,
webhooks and schedules. Locally it's handy for prototyping integrations and for
receiving webhooks from apps under development.

The stack is n8n plus an external task runner (which runs Code nodes), using the
shared pcm postgres (declared in `x-pcm.depends_on`). It is adapted from
[n8n-hosting `withPostgres`](https://github.com/n8n-io/n8n-hosting/tree/main/docker-compose/withPostgres);
the bundled postgres and its `init-data.sh` are replaced by pcm's.

## Run

```sh
pcm up n8n                      # starts postgres if needed, creates the db
pcm down n8n                    # stop (postgres keeps running)
podman compose --pcm logs -f n8n
```

Editor: <http://localhost:5678> — the first visit asks you to create the owner
account.

Data lives in `$PCM_VOLUMES_HOME/n8n/data` (mounted at `/home/node/.n8n`).

> **Memory:** n8n settles around 570 MB and peaks higher while migrating. On a
> 2 GiB podman machine alongside other stacks (authentik alone is ~720 MB) it gets
> OOM-killed and restart-loops, logging "Last session crashed". Give the machine
> more memory (`podman machine set --memory 4096`, with the machine stopped) or
> run fewer stacks at once.

## Configuration

All tunables — images, tag, port, webhook URL, timezone, runner token — and their
defaults live in [`.env.schema`](./.env.schema). To override, add a `.env` next
to it (e.g. stowed from your own ppm layer); none is shipped. Real secrets belong
in fnox.

> **Secret:** `N8N_RUNNERS_AUTH_TOKEN` ships with an insecure dev default. Set a
> real one (`openssl rand -hex 32`) before exposing n8n beyond localhost.

### Encryption key

n8n encrypts stored credentials with a key it generates on first start and saves
in `data/config`. Keep that file with the database: if either is lost, saved
credentials can't be decrypted. To manage the key yourself (e.g. in fnox), add
`N8N_ENCRYPTION_KEY` to the compose environment and schema, using the value from
`data/config` — a key that doesn't match the file stops n8n from starting.

### Upgrading

Bump `N8N_TAG` (it drives both images; they must match). n8n runs database
migrations on start.
