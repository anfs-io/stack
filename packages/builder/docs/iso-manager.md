# ISO Manager

A minimal, single-file Ruby CLI tool for managing ISO file catalogs with download and checksum validation capabilities.

## Overview

ISO Manager helps you maintain a catalog of ISO images (Linux distributions, installation media, etc.) with automatic download capabilities and SHA256 checksum verification. It's designed for personal use across macOS and Debian Linux systems.

## Features

- **Catalog Management**: Store ISO metadata (URL, checksums, architecture, tags) in a YAML configuration file
- **Smart Downloads**: Download ISOs from HTTP/HTTPS URLs with automatic redirect following
- **Checksum Verification**: Automatic SHA256 verification after downloads
- **Interactive Adding**: Easily add new ISOs with automatic attribute detection
- **Status Tracking**: View which ISOs are downloaded vs missing
- **Centralized Storage**: All ISOs stored in `~/.cache/coder/iso`

## Installation

### Prerequisites
- Ruby 3.x
- Thor gem (`gem install thor`)

### Setup

1. **Make executable**:
   ```bash
   chmod +x iso-manager
   ```

2. **Add to PATH** (choose one):
   ```bash
   # Option 1: Copy to system bin
   sudo cp iso-manager /usr/local/bin/

   # Option 2: Symlink from your repo
   ln -s $(pwd)/packages/ruby/home/.local/bin/iso-manager ~/.local/bin/iso-manager
   ```

3. **Verify installation**:
   ```bash
   iso-manager help
   ```

## Configuration

### Config File Location
- **Path**: `~/.config/coder/iso.yml`
- **Auto-created**: On first run if missing

### Config Structure

```yaml
iso_dir: /Users/user/.cache/coder/iso
isos:
  debian-13.1.0-arm64-netinst:
    name: "Debian 13.1.0 Arm64 Netinst"
    url: "https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-13.1.0-arm64-netinst.iso"
    checksum: "sha256:9ecd75a62d90ecedfc3f7fcdf46c349bb4ebfb79553514c9d96239cd9bada820"
    checksum_url: "https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/SHA256SUMS"
    filename: "debian-13.1.0-arm64-netinst.iso"
    architecture: "arm64"
    tags: []
```

**Important**: The `iso_dir` field is **required**. If it's missing, the tool will exit with an error instructing you to add it.

### ISO Storage Location
- **Path**: Configured via `iso_dir` in config file
- **Default suggestion**: `~/.cache/coder/iso` (but can be any path)
- **Auto-created**: On first run if doesn't exist

## Commands

### `iso-manager list`
Display all ISOs in the catalog with their download status.

```bash
$ iso-manager list
ISO Catalog (/Users/user/.config/coder/iso.yml)

debian-13.1.0-arm64-netinst    [Downloaded]  Debian 13.1.0 Arm64 Netinst
ubuntu-24.04-server-amd64      [Missing]     Ubuntu 24.04 Server Amd64

Total: 2 ISOs (1 downloaded, 1 missing)
```

### `iso-manager add`
Interactively add a new ISO to the catalog with automatic attribute detection.

**Features**:
- Extracts filename from URL
- Detects architecture (amd64, arm64, x86_64, aarch64, etc.)
- Generates human-readable name from filename
- Supports checksum URLs or direct SHA256 hashes

**Example**:
```bash
$ iso-manager add
Add New ISO to Catalog

ISO URL: https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso
Checksum (hash or URL): https://releases.ubuntu.com/24.04/SHA256SUMS

Processing...
  ✓ Extracted filename: ubuntu-24.04-live-server-amd64.iso
  ✓ Detected architecture: amd64
  ✓ Downloading checksum file...
  ✓ Extracted checksum: sha256:abc123...

Adding to catalog as: ubuntu-24.04-live-server-amd64

✓ Added to catalog
```

**Checksum Input Options**:
- **URL**: `https://example.com/SHA256SUMS` (downloads and parses automatically)
- **Direct hash**: `9ecd75a62d90ecedfc3f7fcdf46c349bb4ebfb79553514c9d96239cd9bada820`
- **Prefixed hash**: `sha256:9ecd75a62d90ecedfc3f7fcdf46c349bb4ebfb79553514c9d96239cd9bada820`

### `iso-manager download <iso-key>`
Download a specific ISO from the catalog.

**Features**:
- Downloads to `~/.cache/coder/iso`
- Shows progress (size downloaded / total size, percentage)
- Follows HTTP redirects automatically
- Prompts before re-downloading existing files
- Automatically verifies checksum after download

**Example**:
```bash
$ iso-manager download debian-13.1.0-arm64-netinst
Downloading debian-13.1.0-arm64-netinst.iso...
Progress: 350.00 MB / 736.29 MB (47.5%)
```

**Re-download protection**:
```bash
$ iso-manager download debian-13.1.0-arm64-netinst
File exists. Re-download? (y/N) n
```

### `iso-manager download --all`
Download all missing ISOs from the catalog.

**Example**:
```bash
$ iso-manager download --all
Downloading missing ISOs...

[1/2] Downloading debian-12-netinst...
Progress: 650.00 MB / 650.00 MB (100.0%)
✓ Downloaded and verified

[2/2] Downloading ubuntu-24.04-server...
Progress: 2.50 GB / 2.50 GB (100.0%)
✓ Downloaded and verified

Summary: 2 ISOs downloaded successfully
```

### `iso-manager verify <iso-key>`
Verify SHA256 checksum of a specific downloaded ISO.

**Example**:
```bash
$ iso-manager verify debian-13.1.0-arm64-netinst
Verifying debian-13.1.0-arm64-netinst.iso...
✓ Checksum matches: sha256:9ecd75a62d90ec...
```

**On mismatch**:
```bash
$ iso-manager verify debian-13.1.0-arm64-netinst
Verifying debian-13.1.0-arm64-netinst.iso...
✗ Checksum mismatch!
  Expected: sha256:9ecd75a62d90ec...
  Got:      sha256:abc123def456...
```

### `iso-manager verify --all`
Verify checksums of all downloaded ISOs.

**Example**:
```bash
$ iso-manager verify --all
Verifying downloaded ISOs...

debian-13.1.0-arm64-netinst.iso    ✓
ubuntu-24.04-server-amd64.iso      ✓
proxmox-ve-8.iso                   ✗ Checksum mismatch

Summary: 2 passed, 1 failed
```

### `iso-manager status`
Show overview of catalog and disk usage.

**Example**:
```bash
$ iso-manager status
ISO Manager Status

Config: /Users/user/.config/coder/iso.yml
ISO Directory: /Users/user/.cache/coder/iso

Catalog Summary:
  Total ISOs: 3
  Downloaded: 2
  Missing: 1

Disk Usage:
  debian-13.1.0-arm64-netinst.iso    736.29 MB
  ubuntu-24.04-server-amd64.iso      2.50 GB
  Total:                             3.24 GB
```

## Common Workflows

### Adding and downloading a new ISO

```bash
# Add to catalog
iso-manager add
# Enter URL and checksum when prompted

# Download it
iso-manager download <iso-key>

# Verify it
iso-manager verify <iso-key>
```

### Bulk download all missing ISOs

```bash
# See what's missing
iso-manager list

# Download everything
iso-manager download --all

# Verify everything
iso-manager verify --all
```

### Check catalog status

```bash
# Quick overview
iso-manager status

# Detailed list
iso-manager list
```

## Architecture Detection

The tool automatically detects architecture from filenames using these patterns:

| Pattern | Detected As |
|---------|-------------|
| `amd64` | amd64 |
| `x86_64`, `x86-64` | x86_64 |
| `arm64` | arm64 |
| `aarch64` | aarch64 |
| `i386` | i386 |
| `x86` | x86 |
| `armhf` | armhf |
| (none) | unknown |

## Checksum URL Parsing

Supports common checksum file formats:

```
# Format 1: Double space
9ecd75a62d90ec...  debian-13.1.0-arm64-netinst.iso

# Format 2: Asterisk (binary mode)
9ecd75a62d90ec... *debian-13.1.0-arm64-netinst.iso

# Format 3: Tab separator
9ecd75a62d90ec...	debian-13.1.0-arm64-netinst.iso
```

The tool parses these automatically and extracts the correct hash for your ISO.

## Technical Details

### Implementation
- **Language**: Ruby 3.x
- **CLI Framework**: Thor 1.4.x
- **Architecture**: Single-file executable
- **File size**: ~450 lines
- **Dependencies**: Thor gem only (uses Ruby standard library otherwise)

### Key Components

**Classes**:
- `IsoManagerCLI`: Thor-based command-line interface
- `IsoManager`: Core implementation logic

**Technologies Used**:
- `Pathname`: For all file operations
- `Net::HTTP`: For downloads with redirect support
- `Digest::SHA256`: For checksum calculation
- `YAML`: For configuration storage
- `OpenSSL`: For HTTPS with relaxed SSL verification

### SSL Configuration

The tool uses `VERIFY_NONE` for SSL certificate verification to handle various mirror configurations. This is acceptable for ISO downloads because:
1. Checksums are verified after download
2. ISOs are self-contained and verifiable
3. Supports mirrors with non-standard certificates

## Troubleshooting

### "iso_dir not configured" error

**Error message**:
```
Error: 'iso_dir' not configured in /Users/user/.config/coder/iso.yml
Please add the following to your config file:

iso_dir: /path/to/iso/storage
isos:
  ...
```

**Cause**: The `iso_dir` field is missing from your config file.

**Solution**: Edit `~/.config/coder/iso.yml` and add the `iso_dir` field at the top:
```yaml
iso_dir: /Users/user/.cache/coder/iso
isos:
  # your ISOs here
```

You can set `iso_dir` to any path where you want to store your ISOs.

### "No such file or directory @ rb_sysopen - add" error

**Cause**: Using `gets` instead of `$stdin.gets` in interactive prompts.

**Solution**: Already fixed in current version. Update your script if you see this.

### SSL certificate errors

**Cause**: OpenSSL strict certificate verification.

**Solution**: Already handled with `VERIFY_NONE`. Update your script if needed.

### Checksum mismatch after download

**Possible causes**:
1. Download was interrupted or corrupted
2. Wrong checksum in catalog
3. ISO was updated on server

**Solutions**:
1. Re-download: `iso-manager download <iso-key>` (answer 'y' to overwrite)
2. Check the checksum URL manually to verify it's correct
3. Update catalog with new checksum if ISO was updated

### ISO not found in checksum file

**Cause**: The checksum URL doesn't contain an entry for this specific ISO filename.

**Solution**:
1. Download the checksum file manually
2. Find the correct hash
3. Use direct hash instead of URL when adding: `9ecd75a62d90ec...`

## Editing the Catalog

You can manually edit `~/.config/coder/iso.yml` to:
- Configure the `iso_dir` storage location
- Update URLs or checksums
- Add/remove tags
- Change ISO names
- Remove entries

**Example with iso_dir and tags**:
```yaml
iso_dir: /Users/user/.cache/coder/iso
isos:
  debian-13.1.0-arm64-netinst:
    name: "Debian 13.1.0 Arm64 Netinst"
    # ... other fields ...
    tags: ["linux", "debian", "server", "arm"]
```

## Future Enhancements

Currently not implemented but could be added:
- Edit command to modify entries
- Remove command to delete entries
- Search/filter by tags
- MD5 checksum support
- Torrent URL support
- Parallel downloads

## File Locations Reference

| Item | Path |
|------|------|
| Executable | `~/.local/bin/iso-manager` |
| Config file | `~/.config/coder/iso.yml` |
| ISO storage | Configured via `iso_dir` in config (e.g., `~/.cache/coder/iso/`) |
| Source | `packages/ruby/home/.local/bin/iso-manager` |

## License

Built for personal use. Modify as needed.

## Support

For issues or questions, check the source code comments or create an issue in the project repository.
