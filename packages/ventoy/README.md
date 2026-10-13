# ventoy

A wrapper around the upstream [Ventoy](https://www.ventoy.net) release: it prepares a USB stick
(or a disk image) once, and after that an ISO is a file copied onto it.

```bash
ventoy disks                          # USB disks: DEVICE SIZE USB-ID BUS:ADDR MOUNTED NAME
ventoy prepare /dev/sdb               # install Ventoy (Linux; ERASES the disk, asks for its path)
ventoy iso list                       # the catalogue: ID NAME ARCH FILE STATE SIZE
ventoy copy debian proxmox            # download what is missing, select both, copy them
ventoy list                           # what is on the stick, what differs, what is not copied
ventoy sync -y                        # make the stick match the selection exactly
```

`prepare`, `update` and `status` run Ventoy2Disk.sh, which is Linux only. On macOS the wrapper
copies ISOs to a stick that is already prepared (`/Volumes/Ventoy` unless a target is given).

## The catalogue and the store are anfs's

ISOs are named in one catalogue and kept in one store, shared with pmm: `isos/isos.yml` in each
anfs source (stack ships one), `~/.config/anfs/isos.yml` for your own entries, and the files in
`~/.cache/anfs/isos` (`ANFS_ISO_HOME`). `ventoy iso` is the group every tool that uses ISOs has;
`anfs iso` and `pmm iso` are the same commands, from the same code (core's `lib/anfs/iso.sh`):

```bash
ventoy iso list [--all]               # --all: also the files in the store no entry names
ventoy iso show debian                # the entry, which isos.yml defines it, its file and sum
ventoy iso pull [-f] debian           # download and verify, without a stick (alias: get)
ventoy iso add ~/Downloads/some.iso --id some     # your own: copied into the store, pinned
ventoy iso add https://example.org/x.iso --checksum-url https://example.org/SHA256SUMS
ventoy iso remove debian              # delete the file; --entry also drops an entry of your own
ventoy iso path debian
ventoy iso prune                      # delete the files no entry names
```

An amd64 ISO is listed on an arm64 Mac too: putting it on a stick is what this is for.

`ventoy isos` and `ventoy get` are gone: `ventoy iso list` and `ventoy iso pull` replace them,
and selecting for the stick is `ventoy copy <iso>`.

## What goes on the stick

`VENTOY_ISO_DIR` (default `~/.cache/ventoy/isos`) holds the selection: a link into the store for
each ISO `ventoy copy <iso>` was given, and any file put there by hand. Delete one to drop it.

- `ventoy copy <iso>...` downloads an ISO the store does not have, selects it and copies it.
  When the catalogue's entry has moved on to a newer file, that replaces the one selected
  before for the id (`-k` keeps both). The older file stays in the store until
  `ventoy iso prune`.
- `ventoy copy` with no ISO copies everything selected; `ventoy sync` also removes from the
  stick what is not selected (`-n` shows what would change).
- The stick is `-t <target>` for `copy` and `remove`, an argument for `list` and `sync`, and
  `VENTOY_DISK` when neither is given: a disk or its data partition (Linux; mounted for you), a
  disk image file (Linux; attached with losetup and detached again), or a mounted directory.

## A disk image for a PiKVM

A path that does not exist is created as a sparse image: `ventoy prepare ~/ventoy.img --size
32G`. Served over NFS, a PiKVM presents it to its host as a USB flash drive. Never change it
while the PiKVM has it connected: `pikvm msd with -- ventoy sync -y`. The same image boots a
pmm machine: `pmm up <machine> --media "$(ventoy path)"`.

## Tests

```bash
ANFS_TEST_LIB=<core checkout>/packages/anfs/home/.local/lib/anfs bats packages/ventoy/tests </dev/null
```

Offline, under a temp HOME: the stick is a directory, the store is the temp HOME's, `curl` is a
stub. Without `ANFS_TEST_LIB` the installed `~/.local/lib/anfs` is used.
