# ADR-001: Remote Credential Forwarding via 1Password Service Accounts

**Status:** Accepted  
**Date:** 2026-02-09  
**Authors:** Roberto

## Context

We need a way to use CLI tools (`gh`, `aws`, `gcloud`, etc.) on remote Linux hosts without storing credentials on disk. The requirements are:

1. No plaintext secrets written to remote filesystems
2. Centralized credential management with easy revocation
3. Environment isolation (development, staging, production)
4. Minimal friction for day-to-day use
5. Must work over standard SSH connections

We are preparing to go live with production infrastructure (Proxmox, etc.) and need the credential discipline in place before production secrets exist.

## Options considered

### Option 1: 1Password Shell Plugins on each host

Each remote host authenticates independently with 1Password using biometric or interactive login.

**Rejected:** Biometric auth is not available on headless Linux hosts. Interactive login requires a full 1Password account on each machine.

### Option 2: Forward 1Password agent socket over SSH

Similar to SSH agent forwarding, forward the 1Password Unix socket to the remote host.

**Rejected:** The `op` CLI does not use a socket-based protocol suitable for forwarding. This is not officially supported by 1Password.

### Option 3: SSH protocol for git + one-time token injection

Use SSH agent forwarding for git operations, manually inject tokens for API calls via `gh auth login --with-token`.

**Rejected:** Writes the token to `~/.config/gh/hosts.yml` on disk. Doesn't generalize to other tools (AWS, GCP, etc.).

### Option 4: Inject credentials as env vars per SSH session

Export each credential individually from the Mac into the remote shell session.

**Rejected:** Doesn't scale — requires maintaining a growing list of secrets in the SSH wrapper. Each new tool requires modifying the wrapper.

### Option 5: 1Password Service Accounts (selected)

Create a 1Password Service Account with read-only access to environment-specific vaults. Forward a single SA token to the remote host. The remote `op` CLI uses this token to fetch individual credentials on demand.

## Decision

We chose Option 5: 1Password Service Accounts. The approach:

1. **One SA token** is injected into the remote session (via `rssh` wrapper)
2. **Tool wrappers** (`gh`, `aws`, etc.) lazily call `op read` on first invocation
3. **Credentials are cached in env vars** for the session duration — fetched once, reused
4. **SA tokens are cached in macOS Keychain** to avoid repeated `op read` calls on the Mac
5. **Vault naming convention** `SA - <env>` applies to both the vault and the SA credential item

### Vault architecture

```
Admin vault ($OP_SA_CREDENTIALS_VAULT)
  └── SA - development          # SA token (meta-credential)
  └── SA - staging
  └── SA - production

SA - development                # Environment vault (SA has read-only access)
  └── GitHub CLI Token
  └── AWS
  └── ...
```

The SA tokens live in a separate admin vault, not in the environment vaults they grant access to. This avoids circular dependencies and limits the SA's access to only the secrets it needs to serve.

### Platform separation

Shell functions are split across platform-specific directories managed by ppm (PPM_GROUP_ID):

- `home/` — shared functions (`_op_env`, tool wrappers, opcreds aliases)
- `macos/` — keychain caching, `rssh`
- `linux/` — (currently empty, shared functions cover remote host needs)

This eliminates alias/function conflicts between 1Password desktop plugins and our tool wrappers.

## Consequences

### Positive

- No secrets on disk on any remote host
- Single point of revocation per environment (revoke SA token → all access stops)
- Adding new tools is a 3-line wrapper function
- Environment isolation is enforced by vault boundaries
- Keychain caching makes `rssh` fast after first use
- Fully supported by 1Password (Service Accounts are a first-class feature)

### Negative

- Credentials are visible in process environment on the remote host during the session
- SA token in env grants read access to all items in the environment vault
- Requires a 1Password Teams or Business plan for Service Accounts
- Additional dependency on `op` CLI being installed on remote hosts
- Keychain cache must be manually cleared when SA tokens are rotated

### Risks

- If a remote host is compromised while a session is active, the attacker gets the SA token and can read all secrets in that environment's vault until the token is revoked
- Mitigation: read-only access, vault isolation per environment, centralized revocation

## Future considerations

- Evaluate HCP Vault or similar solutions for production environments with stricter security requirements
- Consider short-lived SA tokens if 1Password adds support for token expiration
- SSH config `SetEnv`/`AcceptEnv` for per-host vault mapping when multiple environments are in regular use
