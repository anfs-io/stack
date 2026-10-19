# rpi-imager — notes for Claude

Writes a Raspberry Pi OS image and its cloud-init config to a disk, from a profile kept
in `~/.config/rpi-imager/<name>/`. A profile is **raw cloud-init**, not a schema of our
own: `user-data` and `network-config` are copied to the boot partition essentially
verbatim, with `${VAR}` resolved from the environment.

Read this before changing anything or advising on a remote deployment. Most of what
follows was learned by breaking it, not by reading docs.

## Layout

```
package.yml                      macOS + Linux; cask on macOS, apt deps on Debian
install.sh                       ppm hooks; verifies, never fails the install
home/.local/bin/rpi-imager       the CLI
home/.local/lib/rpi-imager/
  darwin.sh                      macOS disk ops
  linux.sh                       Linux disk ops
home/.config/rpi-imager/example/ reference profile; doubles as documentation
```

`~/.local/bin/rpi-imager` deliberately shares the name of the tool it wraps. **Always
resolve the real binary by absolute path** (`resolve_imager`). On Linux
`/usr/bin/rpi-imager` sits *behind* `~/.local/bin` on PATH, so calling it by name would
re-enter this script forever.

## Platform boundary

Everything OS-specific lives in `home/.local/lib/rpi-imager/<uname -s lowercased>.sh`,
sourced by `load_platform_lib`. The contract is listed at the top of `darwin.sh`.
**Nothing in `bin/rpi-imager` may call `diskutil`, `lsblk`, `findmnt` or `plutil`.** If
you need a new disk capability, add it to the contract and implement it in both libs.

## Things that will bite you

**The Imager CLI cannot write disks on macOS.** As of 2.0.11.1,
`DownloadThread::_openAndPrepareDevice()` → `PlatformQuirks::unmountDisk()` does a
`dispatch_sync` onto a GCD queue that `--cli` mode never services. It deadlocks before
transferring a byte — at any privilege level, disk mounted or not, and there is no flag
to skip it (verified by stack trace). That is why images are written with `dd`. The GUI
is unaffected because it pumps the main queue. Do not "simplify" this back to
`rpi-imager --cli`.

**`--version` output differs by generation and stream.** 2.x prints
`Raspberry Pi Imager v2.0.11.1` on *stdout* with diagnostics on stderr; 1.x printed
`... version 1.8.5` on *stderr* with an empty stdout. Parse both, match a dotted number,
strip a leading `v`.

**`bs=4M`, never `bs=4m`.** GNU dd rejects a lowercase suffix; modern BSD dd accepts
either. `4M` is the only portable spelling.

**`sha256sum` on Linux, `shasum -a 256` on macOS** — `sha256_stdin` picks.

**`image.yml`'s `sha256` is the catalogue's `extract_sha256`** — the hash of the
*decompressed* `.img`, not of the `.img.xz`. Verification therefore streams the image
through the decompressor before writing.

**`${VAR}` inside a comment is documentation, not a reference.** `expand_file` and
`env_refs` both skip full-line comments. Without that, the example profile's own prose
demanded a variable called `VAR`.

**Unset or empty is fatal, deliberately.** `envsubst` substitutes empty and must not be
used. A silently blank password hash produces a Pi nobody can log into, discovered an
hour later.

**Secret masking has an 8-character floor.** Blind substring replacement rewrote every
occurrence of a short value (`user-data` became `u****SSID****er-data`).

**macOS writes AppleDouble `._*` sidecars on FAT** regardless of `cp -X`; the fskit
driver creates them. They are swept after writing.

## cloud-init traps encoded in the example profile

- **Singular `user:`, never plural `users:`.** Plural without `- default` produces an
  account with no sudo/gpio/i2c/spi/video membership (rpi-imager#1601).
- **`runcmd: [[systemctl, enable, --now, ssh]]` is mandatory.** cloud-init's ssh module
  writes keys but never starts sshd, and Pi OS ships it disabled. Without this the Pi
  provisions perfectly and refuses every connection.
- **`instance-id` must change to re-provision**, in *both* `meta-data` and the
  `ds=nocloud;i=` token in `cmdline.txt`. cloud-init's `check_instance_id()` reads the
  kernel cmdline; a stale id there makes it skip provisioning even though `meta-data` is
  new. `cmd_write` rewrites the token rather than only adding it when absent.
- `custom.toml` and `firstrun.sh` are dead on Trixie. Do not reintroduce them.

## Safety model

macOS rejects a target that is `Internal` or non-`Ejectable`. **That test is useless on
Linux** — a USB SSD normally reports `RM=0`, so it would reject the intended target.
`linux.sh` instead refuses any disk backing `/`, `/boot` or `/boot/firmware`
(`disk_of_mount`). Writing the running system's disk is the failure that destroys a
machine; keep that guard.

`disk_eject` on Linux **must not power the device down**. On a Pi about to reboot into
that very disk, a `udisksctl power-off` leaves it electrically absent at boot. It syncs
and unmounts only.

## Remote deployment (Pi 400, USB SSD, no one on site)

Order of operations:

1. `rpi-imager disks` — the system disk is listed and marked, and will be refused.
2. `rpi-imager write <profile> --disk /dev/sdX --all -n` — dry run.
3. `rpi-imager write <profile> --disk /dev/sdX --all`
4. **`rpi-imager verify <profile> --disk /dev/sdX`** — must show 0 failures.
5. `rpi-imager bootorder usb` — sets `BOOT_ORDER=0xf14`.
6. `sudo reboot`

`BOOT_ORDER` nibbles are tried **lowest-significant first**, i.e. the hex reads right to
left. `0xf41` (the firmware default) is SD → USB → loop, so a bootable SD always wins
and the USB disk is never reached. `0xf14` is USB → SD → loop.

**The fallback is narrower than it looks.** `0xf14` falls back to SD only when the USB
disk is *not bootable*. It does nothing for the likely remote failure: the USB boots,
the kernel runs, and the network config is wrong — the boot succeeded, so nothing falls
back, and the box is unreachable until someone stands in front of it. Hence:

- Prefer `dhcp4: true` **alongside** `addresses:` in `network-config`. Netplan supports
  both; you keep a predictable static IP and gain a second way in when the subnet
  assumption is wrong. `verify` warns when this is missing.
- Check for a **PARTUUID collision**. `cmdline.txt` boots `root=PARTUUID=…`; if the SD
  card carries the same PARTUUID the kernel can mount the wrong root. `verify` compares
  the target against every disk backing the running system.
- Consider an auto-rollback: a systemd timer installed via cloud-init that, if it cannot
  reach a known host within ~10 minutes of boot, runs `rpi-eeprom-config` to restore
  `0xf41` and reboots into the SD card. Not implemented here.

## Testing

No test framework; verification is manual. A safe way to exercise the whole write path
without a real card, on macOS:

```bash
hdiutil create -size 200m -fs MS-DOS -volname BOOTFS -layout MBRSPUD /tmp/testcard.dmg
hdiutil attach /tmp/testcard.dmg -nobrowse     # gives an ejectable /dev/diskN
```

Always exercise the failure paths, not just the happy one: unset and empty variables,
two profiles (the chooser), an invalid disk, a stale `instance-id`, plural `users:`, a
missing sshd `runcmd`. Each of those has been a real bug here.
