# Dockge

Web UI for creating, editing and running compose stacks. See
<https://dockge.kuma.pet>.

## Run

```sh
psm up dockge
psm down dockge
```

Web UI: <http://localhost:5001> — create the admin account on first visit.

Requires the podman API socket. On Linux the podman package enables it
(`systemctl --user enable --now podman.socket`); on macOS the podman machine VM
runs it. `psm validate dockge` reports it if it's missing.

## Stacks

Dockge keeps its stacks in `$PSM_VOLUMES_HOME/dockge/stacks/<stack>/compose.yaml`.
To bring an existing compose project under Dockge, move it there and use
**Scan Stacks Folder** in the UI.

These stacks are not psm services: `psm validate` doesn't check them and they
don't get `x-psm` dependencies, provisioning or the shared network. psm services
started with `psm up` still show up in Dockge as running containers — manage
those with psm.

### Why the stacks path is mounted at the same path

Dockge runs `docker compose` inside its container, talking to podman through the
socket. Compose turns relative paths in a stack (e.g. `./data`) into absolute
paths based on where it sees the stack, and podman resolves those on the host.
If the stacks directory were mounted at a different path inside the container,
stack data would be written to the wrong place on the host. compose.yml mounts
`${PSM_VOLUMES_HOME}/dockge/stacks` at that same path and sets
`DOCKGE_STACKS_DIR` to match.

## Security

Dockge can start any container and mount anything your user can access through
the podman socket. With rootless podman that is limited to your user, not root.
The UI binds to 127.0.0.1 by default; set `DOCKGE_BIND` in a `.env` to expose it.

## Configuration

Tunables and their defaults live in [`.env.schema`](./.env.schema). To override
them, add a `.env` next to it (e.g. stowed from your own ppm layer); none is shipped.
