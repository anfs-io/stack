# Builder

A collection of Ruby CLI tools for automating Debian installations, managing ISO catalogs, and creating bootable USB drives with Ventoy.

## Overview

This package provides three integrated tools for infrastructure automation:

- **builder** - Create automated Debian installations using preseed configurations
- **iso-manager** - Manage a catalog of ISO images with download and verification
- **ventoy** - Prepare bootable USB drives with Ventoy multiboot support

Perfect for DevOps engineers, homelabbers, and anyone who needs to provision Debian-based systems at scale.

## Features

### builder

Create unattended Debian installations by serving preseed configurations or repacking ISOs:

- Serve preseed.cfg files over HTTP during installation
- Repack Debian ISOs with preseed URL baked into GRUB
- ERB template system for dynamic configuration
- Cross-platform: native on Linux, container-based on macOS
- Auto-detects local IP address for network installations

### iso-manager

Maintain a versioned catalog of Linux distribution ISOs:

- YAML-based catalog with metadata (URL, checksum, architecture, tags)
- Download ISOs with progress tracking and automatic redirect following
- SHA256 checksum verification
- Interactive adding with automatic attribute detection
- Bulk operations (download all, verify all)
- Disk usage tracking

### ventoy

Automate creation of multiboot USB drives:

- Downloads and installs Ventoy to USB devices
- Handles ISO image wiping and partition setup
- Manages ISO downloads directly to Ventoy partition
- Safety features: device validation, confirmation prompts
- Automatic partition flag management for UEFI boot

## Installation

### Prerequisites

- Ruby 3.0+ (managed via mise, asdf, or rbenv)
- For builder: podman or docker (macOS only)
- For ventoy: Linux system (requires fdisk, parted, xorriso)

### Install via PPM

This package is designed for PPM (Personal Package Manager):

```bash
# Install the package
ppm install builder

# This creates symlinks:
# ~/.local/bin/builder
# ~/.local/bin/iso-manager
# ~/.local/bin/ventoy
# ~/.config/builder/base.yml
# ~/.config/builder/preseed.cfg.erb
```

### Manual Installation

If not using PPM, you can install manually:

```bash
# Clone the repo
git clone https://github.com/yourusername/ppm-packages.git
cd ppm-packages/packages/builder

# Install Ruby dependencies
gem install thor webrick

# Symlink binaries to your PATH
ln -s $(pwd)/home/.local/bin/builder ~/.local/bin/
ln -s $(pwd)/home/.local/bin/iso-manager ~/.local/bin/
ln -s $(pwd)/home/.local/bin/ventoy ~/.local/bin/

# Copy configuration templates
mkdir -p ~/.config/builder
cp home/.config/builder/* ~/.config/builder/
```

## Usage

### builder: Automated Debian Installation

#### Method 1: Serve Preseed (Recommended)

Serve a preseed configuration over HTTP during installation:

```bash
# Create a configuration file
cat > ~/.config/builder/myserver.yml <<EOF
username: admin
password: changeme
authorized_keys_url: https://github.com/yourusername.keys
hostname: web-server-01
domain: example.com
timezone: America/New_York
EOF

# Start the preseed server
builder serve myserver

# Output shows:
# Serving preseed at: http://192.168.1.100:8080/preseed-myserver.cfg
# Boot param: auto=true priority=critical preseed/url=http://192.168.1.100:8080/preseed-myserver.cfg
```

During Debian installation, press `e` at GRUB menu and add the boot parameters shown above.

#### Method 2: Repack ISO

Bake the preseed URL directly into a Debian ISO:

```bash
# Download Debian netinst ISO first
iso-manager download debian-13.1.0-amd64-netinst

# Repack with preseed URL
builder repack myserver \
  --iso ~/.cache/isos/debian-13.1.0-amd64-netinst.iso \
  --output ~/debian-automated.iso

# Don't forget to run the preseed server!
builder serve myserver
```

Boot from the repacked ISO and installation proceeds automatically.

#### Preseed Configuration

The preseed template (`~/.config/builder/preseed.cfg.erb`) supports ERB variables:

- `username` - User account to create
- `password` - User password
- `authorized_keys_url` - URL to fetch SSH public keys
- `hostname` - System hostname
- `domain` - Domain name
- `timezone` - System timezone

Customize `~/.config/builder/preseed.cfg.erb` for advanced configurations (partitioning, package selection, post-install scripts).

### iso-manager: ISO Catalog Management

#### Setup

Create the configuration file:

```bash
mkdir -p ~/.config/builder
cat > ~/.config/builder/iso.yml <<EOF
iso_dir: ~/.cache/isos
isos:
  debian-13.1.0-amd64-netinst:
    name: "Debian 13.1.0 AMD64 Network Installer"
    url: "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso"
    checksum: "sha256:cc6cc024a9acfcdb7ec5cb9e242e98962dba8b7074a5ac39c7e5f73bc4b98ee2"
    filename: "debian-13.1.0-amd64-netinst.iso"
    architecture: "amd64"
    tags: []
EOF
```

#### Common Operations

```bash
# View catalog
iso-manager list

# Add a new ISO interactively
iso-manager add
# Prompts for URL and checksum (URL or direct hash)

# Download a specific ISO
iso-manager download debian-13.1.0-amd64-netinst

# Download all missing ISOs
iso-manager download --all

# Verify checksums
iso-manager verify debian-13.1.0-amd64-netinst
iso-manager verify --all

# Check status and disk usage
iso-manager status
```

#### Architecture Detection

The `add` command automatically detects architecture from filenames:

- `amd64`, `x86_64` → amd64/x86_64
- `arm64`, `aarch64` → arm64/aarch64
- `i386`, `x86`, `armhf` → respective architectures

### ventoy: Bootable USB Creation

**⚠️ Linux only** - Requires root access for disk operations.

#### Create a Ventoy USB

```bash
# List available devices
lsblk

# Prepare USB device (DESTRUCTIVE!)
ventoy prepare /dev/sdb

# This will:
# - Download Ventoy (~100MB)
# - Verify checksum
# - Partition the device
# - Install Ventoy bootloader
```

#### Add ISOs to Ventoy USB

```bash
# Configure ISOs in ~/.config/builder/ventoy.yml
# (or ~/.config/ventoy/config.yml)

# Add ISOs from catalog
ventoy add-iso /dev/sdb2 --mount /mnt/ventoy

# Manually copy ISOs
sudo mount /dev/sdb2 /mnt/ventoy
sudo cp ~/Downloads/*.iso /mnt/ventoy/
sudo umount /mnt/ventoy
```

#### Configuration

Edit `~/.config/ventoy/config.yml`:

```yaml
ventoy:
  version: v1.0.99
  dir: ventoy-1.0.99
  file: ventoy-1.0.99-linux.tar.gz
  checksum: sha256:467cdd188a7f739bc706adbc1d695f61ffdefc95916adb015947d80829f00a3d

iso_files:
  - name: debian-13.1.0-amd64-netinst.iso
    url: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso
    checksum: sha256:cc6cc024a9acfcdb7ec5cb9e242e98962dba8b7074a5ac39c7e5f73bc4b98ee2
```

## Complete Workflow Example

Build an automated Debian installation USB:

```bash
# 1. Setup ISO catalog
iso-manager add
# Enter: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso
# Enter: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS

# 2. Download the ISO
iso-manager download debian-13.1.0-amd64-netinst

# 3. Create preseed configuration
cat > ~/.config/builder/production.yml <<EOF
username: ansible
password: temp123
authorized_keys_url: https://github.com/yourteam.keys
hostname: prod-web-01
domain: production.local
timezone: UTC
EOF

# 4. Repack ISO with preseed
builder repack production \
  --iso ~/.cache/isos/debian-13.1.0-amd64-netinst.iso \
  --output ~/debian-production.iso

# 5. Create bootable USB (Linux only)
ventoy prepare /dev/sdb
sudo mount /dev/sdb2 /mnt/ventoy
sudo cp ~/debian-production.iso /mnt/ventoy/
sudo umount /mnt/ventoy

# 6. Boot from USB and run preseed server
builder serve production
# Leave running during installation
```

Boot from the USB, select the repacked ISO, and watch the automated installation.

## Architecture

### Cross-Platform Design

**builder** adapts to the host platform:

- **Linux**: Uses native `xorriso` and `isolinux` commands
- **macOS**: Runs commands in a Debian container (podman/docker)
- Automatic container runtime detection
- Automatic podman machine management

### Configuration System

**ERB Templates**: Preseed configurations use Ruby's ERB templating:

```erb
d-i netcfg/get_hostname string <%= hostname %>
d-i passwd/username string <%= username %>
d-i preseed/late_command string \
    in-target curl -fsSL "<%= authorized_keys_url %>" -o /home/<%= username %>/.ssh/authorized_keys
```

**YAML Configuration**: Structured data for repeatability:

```yaml
# ~/.config/builder/myserver.yml
username: admin
hostname: web-01
# ... merged with preseed.cfg.erb at runtime
```

### File Locations

| File | Path |
|------|------|
| Binaries | `~/.local/bin/builder`, `iso-manager`, `ventoy` |
| Preseed template | `~/.config/builder/preseed.cfg.erb` |
| Preseed configs | `~/.config/builder/*.yml` |
| ISO catalog | `~/.config/builder/iso.yml` |
| ISO storage | Configured in `iso.yml` (e.g., `~/.cache/isos`) |
| Ventoy config | `~/.config/ventoy/config.yml` |
| Ventoy cache | `~/.cache/ventoy/` |
| Ventoy data | `~/.local/share/ventoy/` |

## Security Considerations

### Preseed Passwords

Preseed configurations contain plaintext passwords. Use with caution:

- Use temporary passwords, change immediately post-install
- Rely on SSH key authentication (via `authorized_keys_url`)
- Store configs securely (e.g., encrypted vault, restricted permissions)
- Use private networks for preseed serving

### ISO Verification

All tools verify SHA256 checksums:

- ISOs downloaded by `iso-manager` are automatically verified
- Ventoy downloads are checksummed
- Prevents corrupted or tampered images

### USB Operations

`ventoy prepare` is destructive:

- Multiple confirmation prompts
- Device validation checks
- System disk detection and warnings
- Requires explicit user confirmation

## Troubleshooting

### builder: Container Runtime Issues

**Error**: `No container runtime found`

```bash
# Install podman (macOS)
brew install podman
podman machine init
podman machine start
```

### iso-manager: Missing iso_dir

**Error**: `'iso_dir' not configured`

Edit `~/.config/builder/iso.yml` and add:

```yaml
iso_dir: ~/.cache/isos
isos:
  # your ISOs
```

### ventoy: Permission Denied

Ventoy requires root access:

```bash
# Ensure sudo access
sudo -v

# Run with proper permissions
ventoy prepare /dev/sdb
```

### Preseed Not Loading

Common issues:

1. **Network unreachable**: Ensure preseed server is on same network
2. **Firewall blocking**: Check port 8080 is accessible
3. **Wrong IP address**: Server shows correct IP, verify it's reachable
4. **Typo in boot params**: Copy-paste the exact string from server output

## Use Cases

### Home Lab

Quickly provision VMs for testing:

```bash
# Create minimal preseed
cat > ~/.config/builder/homelab.yml <<EOF
username: homelab
password: test123
hostname: vm-test
domain: home.local
timezone: America/New_York
EOF

# Serve and install
builder serve homelab
# Boot VM with boot params shown
```

### Production Infrastructure

Standardize bare-metal server provisioning:

```bash
# Production preseed with hardening
# Edit preseed.cfg.erb to add:
# - Disk encryption
# - Security updates
# - Monitoring agents
# - Configuration management bootstrap

# Store in version control
git add ~/.config/builder/production.yml
git commit -m "Add production server preseed"
```

### USB Rescue Toolkit

Create a multiboot USB with recovery tools:

```bash
# Add multiple ISOs to catalog
iso-manager add # Debian
iso-manager add # Ubuntu
iso-manager add # SystemRescue
iso-manager download --all

# Create Ventoy USB
ventoy prepare /dev/sdb
ventoy add-iso /dev/sdb2
```

## Development

### Project Structure

```
packages/builder/
├── home/.local/bin/
│   ├── builder          # 202 lines - Thor CLI, preseed server/repacker
│   ├── iso-manager      # 491 lines - Thor CLI, ISO catalog manager
│   └── ventoy          # 582 lines - Thor CLI, Ventoy installer
├── home/.config/builder/
│   ├── base.yml        # Example preseed configuration
│   └── preseed.cfg.erb # Debian preseed template with ERB
├── docs/
│   └── iso-manager.md  # Detailed iso-manager documentation
├── install.sh          # PPM installation script
└── README.md           # This file
```

### Dependencies

Runtime dependencies (installed automatically):

- `thor` - CLI framework
- `webrick` - HTTP server for preseed serving

Optional dependencies:

- `podman` or `docker` - For macOS ISO repacking
- `xorriso`, `isolinux` - For Linux ISO repacking
- `fdisk`, `parted`, `dosfstools` - For Ventoy USB creation

### Contributing

This is a personal infrastructure automation toolkit. Feel free to fork and adapt to your needs.

## License

Personal use. Modify as needed for your infrastructure.

## See Also

- [Debian Preseed Documentation](https://wiki.debian.org/DebianInstaller/Preseed)
- [Ventoy Project](https://www.ventoy.net/)
- [PPM Package Manager](https://github.com/yourusername/ppm) (if you have a public repo)

## Support

For detailed documentation on individual tools:

- [ISO Manager Documentation](docs/iso-manager.md)
- Built-in help: `builder help`, `iso-manager help`, `ventoy help`
