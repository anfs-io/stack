# Traefik

The pcm proxy (`x-pcm.provides: proxy`): it routes hostnames to pcm services.
See <https://doc.traefik.io/traefik/>. Image, ports, env names and the privilege it
takes: `pcm show traefik`.

## How services use it

A service declares what it serves; it never names Traefik:

```yaml
x-pcm:
  ingress:
    service: server        # compose service (default: the only one)
    port: 3000             # its container port
    healthcheck: /healthz  # default /up
    hosts: ${APP_HOSTS}    # default <name>.localhost
```

`pcm up <service>` starts Traefik first (an implicit dependency) and joins the
service to the shared network. pcm runs this definition's hooks:

- `labels`: prints the Traefik labels (router rule, entry point, port, health
  check) that pcm sets on the service's container. Traefik's docker provider
  reads them over the podman socket, so a route appears when the container
  starts and disappears when it stops. pcm keeps no routing state.
- `provision`: prints the URL of the service's first host, which the service
  gets as `PCM_INGRESS_URL`.

Only containers carrying `io.pcm.ingress=true` (set by pcm) are routed.

## Run

```sh
pcm up traefik            # or just `pcm up <a service with ingress>`
pcm down traefik          # refused while routed services run (or --force)
```

- Services: `http://<name>.localhost:8088`. `*.localhost` resolves to
  loopback in browsers and curl, so this needs no DNS.
- Dashboard: <http://traefik.localhost:8088/dashboard/>. It is routed like any
  other service and is **local only**: never expose it to the internet without
  an auth layer in front.

## Ports

`PROXY_HTTP_PORT` defaults to 8088 and `PROXY_HTTPS_PORT` to 8443, bound to
`PROXY_BIND` (127.0.0.1). 8080 is taken by telemetry's Grafana.

Rootless podman can't publish ports below 1024. On a server that should
answer on 80/443:

```sh
echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee /etc/sysctl.d/90-unprivileged-ports.conf
sudo sysctl --system
```

Then set `PROXY_HTTP_PORT=80`, `PROXY_HTTPS_PORT=443` and `PROXY_BIND=0.0.0.0`
in `~/.config/pcm/containers/traefik/local.env`.

## SELinux

The `security_opt: label=disable` privilege (`x-pcm.privileges`, reason in
`pcm show traefik`) is what lets the docker provider read the podman socket
(`user_tmp_t`). Without it the provider logs `permission denied` and nothing is
routed.
