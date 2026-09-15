# authentik

Self-hosted identity provider — SSO via OAuth2 / OIDC / SAML, plus user and
application management. In a dev environment it stands in for whatever IdP your
app will authenticate against in production, so you can build and test real
OIDC/SAML flows locally.

The stack is the authentik `server` + `worker`, using the shared pcm postgres
(declared in `x-pcm.depends_on`). authentik 2025.10+ needs no Redis.

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

Data (`data/`, `certs/`, `custom-templates/`) lives in
`$PCM_VOLUMES_HOME/authentik/`.

Web UI: <http://localhost:9000> (HTTPS on <https://localhost:9443>). The first
start runs migrations and takes a minute or two.

First-run setup wizard: <http://localhost:9000/if/flow/initial-setup/> — this is
where you set the `akadmin` password.

## Register an application (OIDC)

To let your app authenticate against this authentik, register it as an OIDC
client. Log in as `akadmin`, open the **admin interface**, and go to
**Applications → Applications → Create with wizard** to launch the *New
application* flow. Its five steps:

**1. Application** — how the app appears in authentik.
- **Application Name** *(required)* — display name on the user dashboard, e.g.
  `Rails Dev`.
- **Slug** *(required)* — internal name used in URLs; it becomes part of the
  OIDC endpoints (`/application/o/<slug>/…`), so keep it stable, e.g. `rails-dev`.
- **Group** *(optional)* — apps sharing a group are shown grouped on the dashboard.
- **Policy engine mode** *(required)* — how bound access policies combine:
  **ANY** (any matching policy grants access) or **ALL** (every policy must
  pass). Leave **ANY** for dev.

**2. Choose a Provider** — pick **OAuth2/OpenID Provider** for OIDC (or **SAML
Provider** if your app speaks SAML).

**3. Configure Provider** — the OIDC client settings:
- **Authorization flow** — `default-provider-authorization-explicit-consent`, or
  the `…-implicit-consent` variant to skip the consent screen in dev.
- **Client type** — **Confidential** for a server-side app like Rails (you get a
  client ID *and* secret); **Public** only for SPAs/native apps that can't keep a
  secret.
- **Redirect URIs** — your app's callback, e.g.
  `http://localhost:3000/auth/authentik/callback`. Matched exactly by default.
- Note the generated **Client ID** and **Client Secret** — your app needs both.

**4. Configure Bindings** *(optional)* — bind policies/groups that gate who may
use the app. Skip for open dev access; add a group binding later to restrict it.

**5. Review and Submit** — confirm and create.

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

All tunables — image, ports, secret key — and their defaults live in
[`.env.schema`](./.env.schema), so first run needs nothing beyond pcm's postgres.

To override, add a `.env` next to it (e.g. stowed from your own ppm layer); none
is shipped. Real secrets belong in fnox: a `fnox.toml` in this directory, with
providers in `../fnox.toml`.

> **Secret:** `AUTHENTIK_SECRET_KEY` ships with an insecure dev default. Set a
> real one (`openssl rand -hex 32`) before exposing authentik beyond localhost.

### Embedded outposts (off)

authentik's worker can manage embedded outposts (proxy/LDAP providers) if it has
the container socket at `/var/run/docker.sock` and runs as root. It is off here;
the core IdP — flows, providers, applications — works fully without it. To enable
it, add `${PCM_PODMAN_SOCKET}` to `x-pcm.allow_mounts`, mount it at
`/var/run/docker.sock` on the worker, set `user: root` there, and declare
`PCM_PODMAN_SOCKET` (`@required`) in the schema — as `dockge` does.
