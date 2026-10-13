# stack

The anfs-io packages (ppm), containers (pcm), machine profiles (pmm) and skills (psm), in one anfs source. The toolkit and
its conventions are in the `core` source (anfs-io/system): read its CLAUDE.md for how packages,
layering, hooks and declared software work.

## Structure

```
packages/<name>/     package.yml (required), optional install.sh and home/ (stowed to $HOME)
containers/<name>/   pcm
machines/profiles.yml   pmm: the standard machine shapes (small, medium, large, xlarge)
skills/<name>/       psm
isos/isos.yml        the ISO catalogue (ventoy get, pmm media)
docs/<category>.md   what each category holds
```

Packages are flat. A package's groups are `categories: [...]` in its package.yml (ai, pde, pdt,
utils); a new category needs no directory, only packages that declare it. `depends:` uses bare
names.

## Tools shipped by packages

A script a package puts in `~/.local/bin` is an anfs tool like the core ones: it sources
`~/.local/lib/anfs/{bash,paths,log,cli,table}.sh`, declares its commands with `cli_cmd`, prints
lists through `anfs_table`, and speaks through `anfs_info`/`anfs_warn`/`anfs_die`. Help, the check
of the line, completion (`zcomp <tool>` in the package's zsh file), `--json`, `-d`, `--version`,
the log and the exit codes (64 usage, 69 missing) all come from there. Core's CLAUDE.md has the
rules ("The Command Line", "Lists and --json", "Messages, Debugging and the Log");
`packages/ventoy/home/.local/bin/ventoy` is the model, and each tool has `tests/*.bats`
(`bats packages/<name>/tests </dev/null`).

`isos/isos.yml` is this source's ISO catalogue (core's `lib/anfs/iso.sh`): what `ventoy get <id>`
downloads into the shared store (`~/.cache/anfs/isos`) and what a pmm machine names in `media:`.

On it: `ventoy`, `gem-local` (ruby), `tsm` (tailscale), `opm` (op), `remotefs`, `pikvm`. Not yet:
`rpi-imager`, `firstmate`.

| Command | Keys |
| --- | --- |
| `ventoy disks` | `device`, `size`, `usb_id`, `bus_addr`, `mounted`, `name` |
| `ventoy list` | `size`, `status` (`on stick`, `only on stick`, `differs`, `not copied`), `iso` |
| `ventoy isos` | `id`, `status` (`selected`, `downloaded`, `missing`), `arch`, `file` |
| `gem-local list` | `gem`, `dir`, `note` (`missing`) |
| `gem-local src list` | `path`, `note` (`missing`) |
| `remotefs list` | `label`, `remote`, `mountpoint`, `state` (`mounted`, `unmounted`, `stale`) |
| `pikvm msd list` | `size`, `image` |
| `opm list` | `scope`, `shared`, `service_account`, `token_item`, `token_vault`, `provisioned` |
