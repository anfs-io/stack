# pim - Product Image Manager

A Ruby CLI tool for managing product images (ISOs) and serving preseed configurations for automated OS installations.

## Features

- **Profile-based configuration**: Define reusable installation profiles with deep-merging support
- **ISO management**: Download, verify, and catalog installation ISOs via `pim-iso`
- **Preseed server**: Serve preseed.cfg and post-install scripts via WEBrick
- **Flexible config**: Global, project, and runtime configuration with automatic merging

## Commands

### pim

```bash
pim serve [PROFILE] [ISO]  # Start preseed server
pim list [TYPE]            # List profiles or isos
pim iso SUBCOMMAND         # ISO management (delegated to pim-iso)
```

### pim-iso

```bash
pim-iso list              # Display all ISOs with status
pim-iso download ISO_KEY  # Download a specific ISO
pim-iso verify ISO_KEY    # Verify checksum of an ISO
pim-iso add               # Add a new ISO interactively
pim-iso status            # Show overview of catalog
```

## Configuration

Configuration is loaded from multiple sources and deep-merged:

1. **Global**: `$XDG_DATA_HOME/pim/{profiles,isos}.yml` + `.d/*.yml`
2. **Project**: `$PWD/{profiles,isos,pim}.yml`
3. **Runtime**: `$XDG_CONFIG_HOME/pim.yml` merged with `$PWD/pim.yml`

### Example profiles.yml

```yaml
default:
  username: ansible
  password: changeme
  timezone: UTC
  domain: local

profiles:
  homelab:
    hostname: homelab-vm
    authorized_keys_url: https://github.com/username.keys
```

### Example isos.yml

```yaml
isos:
  debian-13-netinst:
    name: Debian 13 Netinst
    url: https://cdimage.debian.org/.../debian-13.1.0-amd64-netinst.iso
    checksum: sha256:...
    filename: debian-13.1.0-amd64-netinst.iso
```

## Templates

Templates use ERB and are searched in order:

1. `$PWD/{preseeds,post_installs}/[name].[ext]`
2. `$XDG_DATA_HOME/pim/{preseeds,post_installs}/[name].[ext]`
3. Bundled templates (for `default` profile only)
