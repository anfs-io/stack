# GlitchTip

Self-hosted, Sentry-compatible error tracking. Point your app's Sentry SDK at a
GlitchTip DSN and exceptions land here instead of (or alongside) hosted Sentry.

In a dev environment this gives you a local error inbox. The stack is GlitchTip,
using the shared pcm postgres and valkey (declared in `x-pcm.depends_on`). Image,
port, data and env names: `pcm show glitchtip`.

## Run

```sh
pcm up glitchtip                      # starts postgres + valkey if needed, creates the db
pcm down glitchtip                    # stop (postgres and valkey keep running)
podman compose --pcm logs -f glitchtip
```

`pcm up` starts postgres if it isn't running, waits for it to be healthy, creates
the `glitchtip` database and passes the connection string in as
`PCM_POSTGRES_URL`. Plain `podman compose up` in this directory has neither the
database URL nor the defaults from `.env.schema`, so use pcm (or `--pcm`).

Web UI: <http://localhost:8000> — create the first account via the sign-up form
(the first user can be promoted to superuser).

Wire an app to it: create an organization + project in the UI, copy the DSN, and
set it as your Sentry `dsn`.

## Configuration

The defaults in [`.env.schema`](./.env.schema) need nothing beyond pcm's postgres
on first run.

To override, add a `.env` next to it (e.g. stowed from your own ppm layer); none
is shipped. Real secrets belong in fnox: a `fnox.toml` in this directory, with
providers in `../fnox.toml`. pcm resolves the environment first, then `.env`, then
the schema defaults, and validates the result before starting anything.

> **Secret:** `GLITCHTIP_SECRET_KEY` ships with an insecure dev default. Set a
> real one (`openssl rand -hex 32`) before exposing GlitchTip beyond localhost.
