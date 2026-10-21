# stack

The anfs-io packages (ppm), containers (pcm), machine profiles (pmm) and skills (psm), in one anfs source. The toolkit and
its conventions are in the `core` source (anfs-io/system): read its AGENTS.md for how packages,
layering, hooks and declared software work.

## Structure

```
packages/<name>/     package.yml (required), optional install.sh and home/ (stowed to $HOME)
containers/<name>/   pcm
machines/profiles.yml   pmm: the standard machine shapes (small, medium, large, xlarge)
skills/<name>/       psm
isos/isos.yml        the ISO catalogue (anfs iso, ventoy copy, pmm media)
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
the log and the exit codes (64 usage, 69 missing) all come from there. Core's AGENTS.md has the
rules ("The Command Line", "Lists and --json", "Messages, Debugging and the Log");
`packages/ventoy/home/.local/bin/ventoy` is the model, and each tool has `tests/*.bats`
(`bats packages/<name>/tests </dev/null`).

`isos/isos.yml` is this source's ISO catalogue (core's `lib/anfs/iso.sh`): what `anfs iso pull <id>`
downloads into the shared store (`~/.cache/anfs/isos`), what `ventoy copy <id>` puts on a stick
and what a pmm machine names in `media:`. The `iso` group (`list`, `show`, `pull`, `add`,
`remove`, `path`, `prune`) is core's, written once and adopted by `anfs`, `pmm` and `ventoy`
with one call (`anfs_iso_cli`); its keys are in core's table.

On it: `ventoy`, `gem-local` (ruby), `tsm` (tailscale), `opm` (op), `remotefs`, `pikvm`, `ssh-key`
(ssh), `git-account` (git: run as `git account`), `ovm` (obsidian). Not yet:
`rpi-imager`, `firstmate`.

| Command | Keys |
| --- | --- |
| `ventoy disks` | `device`, `size`, `usb_id`, `bus_addr`, `mounted`, `name` |
| `ventoy list` | `size`, `status` (`on stick`, `only on stick`, `differs`, `not copied`), `iso` |
| `gem-local list` | `gem`, `dir`, `note` (`missing`) |
| `gem-local src list` | `path`, `note` (`missing`) |
| `remotefs list` | `label`, `remote`, `mountpoint`, `state` (`mounted`, `unmounted`, `stale`) |
| `pikvm msd list` | `size`, `image` |
| `ssh-key list` | `key` (the fingerprint), `status` (`local`, `agent`), `file`, `type`, `comment`, `public` |
| `git account list` | `account` (`<host>/<user>`), `status` (`key on account`, `no key here`, `key not on account`, `unreachable`), `keys` (how many the account has), `host`, `user` |
| `ovm list` | `name`, `id`, `status` (`ok`, `stale`, `unreachable`), `path` |
| `ovm link list` | `source`, `target`, `as`, `status` (`ok`, `pending`, `missing`, `conflict`, `dangling`, `unknown`), `link`, `vault` |
| `ovm docs` | `id`, `type`, `title`, `space`, `path`, `vault` |
| `ovm validate` | `path`, `finding` |
| `opm list` | `scope`, `shared`, `service_account`, `token_item`, `token_vault`, `provisioned` |
