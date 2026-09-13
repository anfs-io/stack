# GlitchTip

Self-hosted, Sentry-compatible error tracking. Point your app's Sentry SDK at a
GlitchTip DSN and exceptions land here instead of (or alongside) hosted Sentry.

In a dev environment this gives you a local error inbox. The stack is GlitchTip +
Valkey, using the shared psm postgres (declared in `x-psm.depends_on`).

## Run

```sh
psm up glitchtip                      # starts postgres if needed, creates the db
psm down glitchtip                    # stop (postgres keeps running)
podman compose --psm logs -f glitchtip
```

`psm up` starts postgres if it isn't running, waits for it to be healthy, creates
the `glitchtip` database and passes the connection string in as
`PSM_POSTGRES_URL`. Plain `podman compose up` in this directory won't have a
database URL, so use psm (or `--psm`).

Web UI: <http://localhost:8000> — create the first account via the sign-up form
(the first user can be promoted to superuser).

Wire an app to it: create an organization + project in the UI, copy the DSN, and
set it as your Sentry `dsn`.

## Configuration

All tunables — images, ports, connections, feature flags — are documented in
[`.env.schema`](./.env.schema), which is the canonical reference. Defaults are
baked into `compose.yml`, so first run needs nothing beyond psm's postgres.

To override, copy [`.env.example`](./.env.example) to `.env` and edit. `.env` is
git-ignored.

> **Secret:** `GLITCHTIP_SECRET_KEY` ships with an insecure dev default. Set a
> real one (`openssl rand -hex 32`) before exposing GlitchTip beyond localhost.
