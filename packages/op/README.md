# op - 1Password Credential Management

This package provides two complementary tools for managing credentials via 1Password:

1. **Shell integration** — Secure credential forwarding to remote hosts via 1Password Service Accounts, with lazy-loading tool wrappers for `gh`, `aws`, etc.
2. **opcreds CLI** — A Ruby CLI for creating, retrieving, rotating, and managing infrastructure credentials stored in 1Password.

## Prerequisites

- 1Password desktop app (macOS)
- 1Password CLI (`op`) — installed via mise
- A 1Password plan that supports Service Accounts (Teams or Business)

## Quick Start

### 1. Set up 1Password vaults

Create the following vault structure in 1Password:

```
Admin vault (e.g. "Private")        # Your personal admin vault
  └── SA - development              # Service account token for dev environment
  └── SA - staging                  # Service account token for staging
  └── SA - production               # Service account token for production

SA - development                    # Environment vault (SA has read-only access)
  └── GitHub CLI Token              # field: credential
  └── AWS                           # fields: access key id, secret access key
  └── ...

SA - staging                        # Same structure per environment
  └── ...
```

The naming convention is `SA - <env>` for both the vault and the service account credential item.

### 2. Create a 1Password Service Account

1. Go to https://my.1password.com and create a service account
2. Grant it **read-only** access to the environment vault(s) (e.g. `SA - development`)
3. Store the service account token in your admin vault as `SA - development` with a `credential` field

### 3. Set the admin vault env var

Set `OP_SA_CREDENTIALS_VAULT` to the name of the vault containing your SA tokens. This is typically set in a separate config file outside this package:

```bash
export OP_SA_CREDENTIALS_VAULT="Private"
```

### 4. SSH to a remote host

```bash
# Default environment (development)
rssh myhost

# Specific environment
OP_VAULT=staging rssh myhost
```

On the remote host, tools that have wrappers will automatically fetch credentials on first use:

```bash
gh pr list          # lazily fetches GH_TOKEN from 1Password
aws s3 ls           # lazily fetches AWS credentials from 1Password
```

## Architecture

### Credential flow

```
Mac (rssh)
  │
  ├── Reads SA token from macOS Keychain (cached)
  │   └── Falls back to: op read op://$OP_SA_CREDENTIALS_VAULT/SA - <env>/credential
  │
  └── SSH to remote host with:
      ├── OP_SERVICE_ACCOUNT_TOKEN  (the SA token)
      └── OP_VAULT                  (e.g. "SA - development")

Remote host (tool wrappers)
  │
  └── On first tool invocation:
      └── op read op://$OP_VAULT/<item>/<field>
          └── Credential cached in env var for session duration
```

### File structure

```
home/.config/zsh/op/op.zsh         # Shared (macOS + Linux)
  ├── _op_env()                    # Lazy credential loader
  ├── gh(), aws()                  # Tool wrappers (only when SA token present)
  ├── opcreds aliases              # opc, opget, opnew, opls
  ├── openv()                      # Load single secret to env var
  └── opsource()                   # Inject secrets from template file

macos/.config/zsh/op/macos.zsh     # macOS only
  ├── _op_sa_token()               # Keychain cache: get or fetch SA token
  ├── _op_sa_token_clear()         # Remove cached SA token from keychain
  ├── _op_sa_token_list()          # List cached SA tokens
  └── rssh()                       # SSH with SA token injection
```

### Security model

- **No secrets on disk** — Credentials are never written to files on remote hosts
- **Read-only service accounts** — SA tokens can only read from their assigned vault
- **Env var scoping** — Credentials live only in the shell session and are gone when it ends
- **Keychain caching** — SA tokens are cached in macOS Keychain (encrypted at rest), not in files
- **Vault isolation** — Each environment has its own vault and SA; compromising one doesn't leak others
- **Centralized revocation** — Revoke an SA token in 1Password and all remote access stops immediately

### Known trade-offs

- Credentials are visible in the process environment (`/proc/<pid>/environ`) on the remote host while the session is active
- The SA token grants read access to all items in the environment vault for the duration of the session
- macOS Keychain caching means the SA token persists locally until explicitly cleared

## Shell functions reference

### macOS only

| Function | Description |
|---|---|
| `rssh <host>` | SSH to host with SA token and vault injected |
| `_op_sa_token <env>` | Get SA token (from keychain or 1Password) |
| `_op_sa_token_clear <env>` | Remove cached SA token from keychain |
| `_op_sa_token_list` | List all cached SA tokens |

### Shared (macOS + Linux)

| Function | Description |
|---|---|
| `_op_env <VAR> <item/field>` | Lazily load a credential into an env var |
| `gh`, `aws` | Wrapper functions that auto-fetch credentials |
| `openv <ref> [VAR]` | Load a single 1Password secret into env |
| `opsource [file]` | Inject secrets from a template file |

## Environment variables

| Variable | Set by | Description |
|---|---|---|
| `OP_SA_CREDENTIALS_VAULT` | User config | Vault containing SA tokens (required on macOS) |
| `OP_VAULT` | `rssh` / user override | Environment name override (default: `development`) |
| `OP_SERVICE_ACCOUNT_TOKEN` | `rssh` | SA token injected into remote session |

## Adding tool wrappers

To add credential loading for a new tool, add a wrapper in `home/.config/zsh/op/op.zsh` inside the `if [[ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]]` block:

```bash
gcloud() {
  _op_env GOOGLE_APPLICATION_CREDENTIALS_JSON 'GCP Service Account/credential'
  command gcloud "$@"
}
```

Then add the corresponding item (e.g. `GCP Service Account`) with the appropriate field to each environment vault in 1Password.

## Testing

```bash
cd packages/op
bats tests/keychain.bats    # macOS keychain caching tests
bats tests/shared.bats      # Shared function tests
```

## Keychain management

```bash
# First rssh call caches the SA token (may prompt biometric)
rssh myhost

# Subsequent calls are instant (reads from keychain)
rssh myhost

# Clear a cached token (e.g. after rotation)
_op_sa_token_clear development

# List cached tokens
_op_sa_token_list
```
