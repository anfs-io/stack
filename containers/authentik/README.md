# authentik

Self-hosted identity provider — SSO via OAuth2 / OIDC / SAML, plus user and
application management. In a dev environment it stands in for whatever IdP your
app will authenticate against in production, so you can build and test real
OIDC/SAML flows locally.

The stack is the authentik `server` + `worker`, using the shared pcm postgres
(declared in `x-pcm.depends_on`). authentik 2025.10+ needs no Redis. Images, ports,
data and env names: `pcm show authentik`.

## Run

```sh
pcm up authentik                      # starts postgres if needed, creates the db
pcm down authentik                    # stop (postgres keeps running)
podman compose --pcm logs -f authentik
```

`pcm up` starts postgres if it isn't running, waits for it to be healthy, creates
the `authentik` database and passes the connection details in as
`PCM_POSTGRES_*`. Plain `podman compose up` in this directory has neither those
nor the defaults from `.env.schema`, so use pcm (or `--pcm`).

Web UI: <http://localhost:9000> (HTTPS on <https://localhost:9443>). The first
start runs migrations and takes a minute or two; the `ak healthcheck` checks on
server and worker hold dependents back until it is done.

### Admin login (bootstrap)

On its first start against an empty database authentik creates `akadmin` from
`AUTHENTIK_BOOTSTRAP_PASSWORD` and `AUTHENTIK_BOOTSTRAP_EMAIL`, so there is no setup
wizard. The defaults (`dev-insecure-akadmin`, `akadmin@localhost`) are INSECURE
dev values; override them in `local.env` before the first start for anything shared.
Both are read only on that first start: afterwards change the password in authentik.

The database lives in the shared postgres, not under this definition's data dir, so
an `authentik` database that already existed keeps its admin (bootstrap is skipped).
If that admin has no password (the wizard was never finished), set one with
`pcm exec -s worker authentik -- ak changepassword akadmin`.

## Register an application (OIDC)

### From a dependent: the provision hook

A definition that depends on authentik gets an OAuth2/OpenID client registered on
`pcm up`, and it is removed again on `pcm remove`:

```yaml
x-pcm:
  depends_on:
    authentik:
      slug: shop                        # required: app slug and client_id
      redirect: http://localhost:3000/auth/callback   # required
      name: Shop                        # optional, default: slug
      # client_type: public             # default; confidential is not supported yet
```

| Setting | |
|---|---|
| `slug` | Required. Application slug and OIDC `client_id`; a DNS label (`[a-z0-9][a-z0-9-]*`) |
| `redirect` | Required. Strict-match redirect URI(s): repeat `redirect=` as args, or give a comma-separated list (the only form a YAML map can hold) |
| `name` | Display name, default the slug |
| `client_type` | `public` (default: PKCE, no secret). `confidential` fails with "not yet supported" |

It prints, and pcm injects as `PCM_AUTHENTIK_<KEY>`:

| Key | Value |
|---|---|
| `ISSUER` | `http://localhost:${AUTHENTIK_HTTP_PORT}/application/o/<slug>/` |
| `CLIENT_ID` | `<slug>` |
| `CLIENT_TYPE` | `public` |

The issuer is the host's `localhost` URL: the intended consumer is an app run on
the host (e.g. a Rails dev server), and the issuer in tokens follows the host the
browser used.

An app that isn't a pcm definition calls the same hooks through pcm:

```sh
pcm provision --as partitia/shop authentik slug=shop \
  redirect=http://localhost:3000/auth/callback redirect=http://127.0.0.1:3000/auth/callback
pcm provision --json authentik slug=shop redirect=...    # the keys as a JSON object
pcm deprovision --as partitia/shop authentik slug=shop
```

How it works: `provision` writes the blueprint `pcm-<slug>.yaml` into
`${PCM_VOLUMES_HOME}/authentik/blueprints/` (mounted on the worker at
`/blueprints/custom`) and applies it synchronously with
`podman exec <worker> ak apply_blueprint custom/pcm-<slug>.yaml`. The blueprint
defines a public OAuth2/OpenID provider (`client_id` = slug, strict redirect URIs,
the built-in self-signed signing key, the implicit-consent authorization flow, the
default invalidation flow, the openid/email/profile scopes, grant types
`authorization_code` and `refresh_token`) and the application bound to it. It is
labelled `instantiate: "false"`, so the worker's file discovery leaves it alone and
only the hooks apply it. Applying is idempotent; every `pcm up` re-applies it, which
also puts back anything edited in the UI. `deprovision` rewrites the file with
`state: absent`, applies it, checks the app and provider are gone, then deletes it.

### By hand

Log in as `akadmin`, open the admin interface and use **Applications →
Applications → Create with wizard**: an **OAuth2/OpenID Provider**, client type
**Public** (PKCE) or **Confidential**, your callback as a strict redirect URI, and
in 2026.x make sure the authorization-code grant type is enabled on the provider.

### Connect your app

authentik publishes standard OIDC discovery per application — point your client's
OIDC library at this one URL and it auto-configures the rest:

```
http://localhost:9000/application/o/<slug>/.well-known/openid-configuration
```

If your client needs endpoints spelled out explicitly:

| Purpose | URL |
|---|---|
| Issuer | `http://localhost:9000/application/o/<slug>/` |
| Authorization | `http://localhost:9000/application/o/authorize/` |
| Token | `http://localhost:9000/application/o/token/` |
| Userinfo | `http://localhost:9000/application/o/userinfo/` |
| JWKS | `http://localhost:9000/application/o/<slug>/jwks/` |
| End session | `http://localhost:9000/application/o/<slug>/end-session/` |

An app running in a container on the shared network (`dev-net`) can't use
`localhost`; the issuer in tokens is whatever host the browser used, so keep the
browser and the app agreeing on one URL.

## Configuration

The defaults in [`.env.schema`](./.env.schema) need nothing beyond pcm's postgres
on first run. To override, put the lines in `~/.config/pcm/containers/authentik/local.env`; no
`.env` is shipped. Real secrets belong in fnox: a `fnox.toml` in this directory, with
providers in `../fnox.toml`.

> **Secrets:** `AUTHENTIK_SECRET_KEY` and `AUTHENTIK_BOOTSTRAP_PASSWORD` ship with
> insecure dev defaults. Set real ones (`openssl rand -hex 32`) before exposing
> authentik beyond localhost.

### Embedded outposts (off)

authentik's worker can manage embedded outposts (proxy/LDAP providers) if it has
the container socket at `/var/run/docker.sock` and runs as root. It is off here;
the core IdP — flows, providers, applications — works fully without it. To enable
it, add `${PCM_PODMAN_SOCKET}` to `x-pcm.allow_mounts`, mount it at
`/var/run/docker.sock` on the worker, set `user: root` there, and declare
`PCM_PODMAN_SOCKET` (`@required`) in the schema — as `dockge` does.
