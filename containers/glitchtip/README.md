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

Web UI: <http://localhost:8000> (`GLITCHTIP_PORT`). Log in as the admin
(`GLITCHTIP_ADMIN_EMAIL` / `GLITCHTIP_ADMIN_PASSWORD`), which the provision hook
creates; no sign-up form needed.

## Getting a DSN

The `provision` hook sets GlitchTip up for a consumer and prints its DSN, through
the Django ORM in the web container. pcm runs it once `web` is healthy.

A pcm definition declares it:

```yaml
x-pcm:
  depends_on:
    glitchtip:
      project: shop          # required
      # org: dev             # default dev
      # platform: ruby-rails # default ruby-rails (GlitchTip's platform name)
```

and gets `PCM_GLITCHTIP_DSN` and the other keys below. A host-run app, such as a
Rails app using sentry-rails, asks pcm directly:

```sh
pcm provision --as partitia/shop glitchtip project=shop    # KEY=VALUE on stdout
pcm deprovision --as partitia/shop glitchtip project=shop  # when it's gone
```

| Arg | Default | |
|-----|---------|-|
| `project` | (required) | project slug, `^[a-z0-9][a-z0-9-]*$` |
| `org` | `dev` | organization slug, same pattern |
| `platform` | `ruby-rails` | project platform, same pattern |

It get-or-creates the admin superuser (an existing user's password is never
reset), the org with the admin as owner, a team named after the org (GlitchTip's UI
shows projects to their teams' members), the project on that team, and its client
key. Re-running changes nothing and prints the same values:

| Key | Value |
|-----|-------|
| `DSN` | `http://<key>@localhost:<GLITCHTIP_PORT>/<project id>`, for an app on the host. The UI shows the same one (`GLITCHTIP_DOMAIN` follows `GLITCHTIP_PORT`). |
| `INTERNAL_DSN` | the same key at `http://<web container>:8000/<project id>`, for a pcm container on the shared network |
| `ORG`, `PROJECT` | the slugs |
| `URL` | the project's issues page, `http://localhost:<port>/<org>/issues?project=<id>` |

The DSN is a credential: the hooks never log it. `deprovision` (run by
`pcm remove <dependent>`, or `pcm deprovision`) deletes the project with its
events. It never deletes the org, team or admin: GlitchTip records nothing about who
created an org, so it can't tell an org the hook made from one in use.

GlitchTip reserves some slugs (`admin`, `api`, `issues`, ... for orgs, `new` for
projects); provision fails on those rather than renaming.

By hand instead: log in, create an organization and a project, and copy the DSN
from the project's settings. That DSN is the `DSN` above.

## Configuration

The defaults in [`.env.schema`](./.env.schema) need nothing beyond pcm's postgres
on first run.

To override, put the lines in `~/.config/pcm/containers/glitchtip/local.env`; no
`.env` is shipped. Real secrets belong in fnox: a `fnox.toml` in this directory, with
providers in `../fnox.toml`. pcm resolves the environment first, then `local.env`,
then the schema defaults, and validates the result before starting anything.

> **Secrets:** `GLITCHTIP_SECRET_KEY` and `GLITCHTIP_ADMIN_PASSWORD` ship with
> insecure dev defaults. Set real ones (`openssl rand -hex 32`) before exposing
> GlitchTip beyond localhost. The admin password only applies when provision first
> creates the user; change it in the UI after that.

If you move the UI off `localhost`, set `GLITCHTIP_DOMAIN`: the UI then shows DSNs
on that host, while provision's `DSN` stays on `localhost:<GLITCHTIP_PORT>`.
