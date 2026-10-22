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
the log and the exit codes (64 usage, 69 missing) all come from there. A tool with settings calls
`anfs_tool_paths <tool>` after `paths.sh` and ships `home/.config/<tool>/<tool>.env` documenting
every one (`#NAME=default`, prefixed with the tool's name); a machine's values go in
`<tool>.local.env` beside it (core's AGENTS.md, "Configuration"), and has the `config` group:
it sources `config.sh` when core has it and calls `anfs_config_declare` before `cli_standard`
(`! declare -F anfs_config_declare >/dev/null || anfs_config_declare`). remotefs, ventoy, pikvm, tsm,
opm and ovm do. Core's AGENTS.md has the
rules ("The Command Line", "Lists and --json", "Messages, Debugging and the Log");
`packages/ventoy/home/.local/bin/ventoy` is the model, and each tool has `tests/*.bats`
(`bats packages/<name>/tests </dev/null`). A tool's `cd` is core's pattern too: `cli_cmd cd` whose
`cmd_cd` only says the shell function is missing, and a wrapper in the package's
`home/.config/sh/<tool>.sh` through `_anfs_cd` (core's AGENTS.md, "Shell Integration"); `ovm cd`
is the one here.

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
| `gem-local list` | `gem`, `status` (`ok`, `missing`: the link's repo dir is gone), `dir` |
| `gem-local src list` | `path`, `status` (`ok`, `missing`) |
| `remotefs list` | `label`, `remote`, `mountpoint`, `state` (`mounted`, `unmounted`, `stale`) |
| `pikvm msd list` | `size`, `image` |
| `ssh-key list` | `key` (the fingerprint), `status` (`local`, `agent`), `file`, `type`, `comment`, `public` |
| `git account list` | `account` (`<host>/<user>`), `status` (`key on account`, `no key here`, `key not on account`, `unreachable`), `keys` (how many the account has), `host`, `user` |
| `ovm list` | `name`, `id`, `status` (`ok`, `unreachable`, `not a vault`), `path` (the entries of `~/vaults`) |
| `ovm space list` | `space` (a vault space), `to` (a wsm space), `as`, `status` (`ok`, `pending`, `unlinked`, `missing`, `conflict`, `unknown`, `no folder`, `dangling`, `no vault`, `orphan`), `link`, `vault`, `path` (the folder) |
| `ovm docs` | `id`, `type`, `title`, `space` (the vault space), `path`, `vault` |
| `ovm validate` | `path`, `finding` |
| `opm list` | `scope`, `shared`, `service_account`, `token_item`, `token_vault`, `provisioned` |
