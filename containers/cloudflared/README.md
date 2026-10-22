# cloudflared

The Cloudflare Tunnel connector behind pcm's `cloudflare-tunnel` edge. You don't
start it yourself: a service with a host under a Cloudflare domain depends on it.
Image, env names and links: `pcm show cloudflared`.

## Setup (once)

1. Map your Cloudflare domains to the edge in `~/.config/pcm/edges.yml`:

   ```yaml
   roteoh.com: { provider: cloudflare-tunnel }
   ```

2. Give pcm a Cloudflare API token with **Zone:Read**, **DNS:Edit** (the zones)
   and **Account: Cloudflare Tunnel:Edit**, as `CLOUDFLARE_API_TOKEN`. Through
   fnox, so it comes from 1Password, in `~/.config/pcm/fnox.toml`:

   ```toml
   [secrets]
   CLOUDFLARE_API_TOKEN = { provider = "onepass", value = "op://<vault>/<item>/credential" }
   ```

## Publishing a service

Set its hosts in this machine's settings for it and bring it up:

```sh
mkdir -p ~/.config/pcm/containers/twenty
echo 'TWENTY_HOSTS=crm.roteoh.com' >> ~/.config/pcm/containers/twenty/local.env
pcm up twenty
```

On `up`, the edge finds the zone, creates this machine's tunnel (`pcm-<hostname>`)
if it doesn't exist, points it at the proxy, writes the tunnel token into pcm's
state (`~/.local/state/pcm/containers/cloudflared/state.env`, mode 0600, read
below `local.env`; `pcm show cloudflared` names it), and adds a proxied CNAME `crm → <tunnel id>.cfargotunnel.com`. It never
replaces an existing record for the name. `pcm remove twenty` deletes the CNAME
(only if it points at this tunnel); the tunnel stays.

The service gets `PCM_INGRESS_URL=https://crm.roteoh.com`. Cloudflare terminates
TLS; the proxy behind the tunnel serves plain HTTP.
