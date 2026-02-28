# gam7

Google Workspace administration via [GAM7](https://github.com/GAM-team/GAM).

## Directory Layout

| Path | Purpose |
|------|---------|
| `~/.config/mise/conf.d/gam7.toml` | mise tool config (`pipx:gam7`) |
| `~/.config/gam7/` | GAM config dir (`GAMCFGDIR`): gam.cfg, cache |
| `~/.local/share/gam7/` | GAM working dir (`drive_dir`): CSV exports, reports |
| `~/.config/zsh/gam7.zsh` | Shell env: `GAMCFGDIR` export, `gam` wrapper, aliases |

## Post-Install

Open a new shell (to load `GAMCFGDIR`), then authenticate:

```sh
gam create project
gam oauth create
gam user you@domain.com check serviceaccount
```

## 1Password Integration

GAM reads credentials from files on disk. The `gam` shell wrapper can inject these from 1Password on each invocation so that credentials never persist on the filesystem (temp files are cleaned up after each call, and live under `$TMPDIR` / `/tmp` which are purged on reboot).

### Setup

1. Complete the initial GAM authentication (above) to generate the credential files.

2. Store each file as a 1Password item:

   | File | Suggested item name |
   |------|-------------------|
   | `~/.config/gam7/oauth2.txt` | `gam7-oauth2` |
   | `~/.config/gam7/oauth2service.json` | `gam7-oauth2service` |
   | `~/.config/gam7/client_secrets.json` | `gam7-client-secrets` |

3. Export the `op://` references in your shell (e.g. in a private zsh config):

   ```sh
   export GAM7_OP_OAUTH2="op://Private/gam7-oauth2/credential"
   export GAM7_OP_OAUTH2SERVICE="op://Private/gam7-oauth2service/credential"
   export GAM7_OP_CLIENT_SECRETS="op://Private/gam7-client-secrets/credential"
   ```

4. Remove the local credential files from `~/.config/gam7/` (keep `gam.cfg` and `gamcache/`).

### Behavior

- All three `GAM7_OP_*` vars set + `op` available: credentials pulled from 1Password into temp files per invocation.
- Any var unset or `op` unavailable: falls back to local files in `GAMCFGDIR`.
- If `op read` fails (not signed in, wrong reference): warns to stderr and falls back.

### Note on token refresh

GAM refreshes its OAuth2 access token on each invocation and writes it back to `oauth2.txt`. With the wrapper, refreshed tokens are written to the temp file and discarded. This means every invocation performs a token refresh — functionally correct, negligible overhead.

## Removal

`ppm remove gam7` uninstalls the mise-managed tool and stowed configs. Config (`~/.config/gam7/`) and data (`~/.local/share/gam7/`) are preserved by default.

To remove everything including config and data:

```sh
ppm remove -f gam7
```
