# 1password - macOS specific

# ─────────────────────────────────────────────────────────────────────────────
# Service Account Token Caching (macOS Keychain)
# ─────────────────────────────────────────────────────────────────────────────
# Cache 1Password service account tokens in macOS Keychain so they don't
# require an `op read` call on every SSH session. Tokens are keyed by
# environment name (e.g., DevCreds, Staging, Production).

# Store or retrieve a cached SA token for a given environment.
# Usage: _op_sa_token <env_name>
#   env_name: The environment/vault name (used as keychain key)
#
# Requires: OP_SA_CREDENTIALS_VAULT to be set (the vault containing SA items).
# Reads from: op://$OP_SA_CREDENTIALS_VAULT/SA - <env_name>/credential
_op_sa_token() {
  local env_name="$1"
  local keychain_key="op-sa-token-${env_name}"
  local token

  if [[ -z "$OP_SA_CREDENTIALS_VAULT" ]]; then
    echo "Error: OP_SA_CREDENTIALS_VAULT is not set" >&2
    return 1
  fi

  # Try keychain first
  token=$(security find-generic-password -a "$USER" -s "$keychain_key" -w 2>/dev/null)

  if [[ -z "$token" ]]; then
    # Not cached — fetch from 1Password and cache it
    local op_ref="op://${OP_SA_CREDENTIALS_VAULT}/SA - ${env_name}/credential"
    token=$(op read "$op_ref" 2>/dev/null)
    if [[ -z "$token" ]]; then
      echo "Error: Failed to read SA token for '${env_name}' from ${op_ref}" >&2
      return 1
    fi
    security add-generic-password -a "$USER" -s "$keychain_key" -w "$token" 2>/dev/null
  fi

  echo "$token"
}

# Remove a cached SA token from keychain.
# Usage: _op_sa_token_clear <env_name>
_op_sa_token_clear() {
  local env_name="$1"
  if [[ -z "$env_name" ]]; then
    echo "Usage: _op_sa_token_clear <env_name>" >&2
    return 1
  fi
  local keychain_key="op-sa-token-${env_name}"
  security delete-generic-password -a "$USER" -s "$keychain_key" 2>/dev/null
  echo "Cleared cached SA token for '${env_name}'"
}

# List all cached SA tokens in keychain.
_op_sa_token_list() {
  security dump-keychain 2>/dev/null | grep -B5 '"op-sa-token-' | grep '"svce"' | \
    sed 's/.*"svce"<blob>="op-sa-token-\(.*\)"/  \1/'
}

# ─────────────────────────────────────────────────────────────────────────────
# Remote SSH with 1Password Service Account
# ─────────────────────────────────────────────────────────────────────────────
# SSH to a remote host, injecting the service account token and vault name
# into the remote session. The vault/environment is determined by:
#   1. OP_VAULT env var override:  OP_VAULT=staging rssh myhost
#   2. Default:                    development

rssh() {
  local vault="${OP_VAULT:-development}"
  local op_sa_token

  op_sa_token=$(_op_sa_token "$vault")
  if [[ $? -ne 0 ]]; then
    echo "Error: Could not retrieve SA token for vault '${vault}'" >&2
    return 1
  fi

  ssh -t "$@" "
    export OP_SERVICE_ACCOUNT_TOKEN='${op_sa_token}'
    export OP_VAULT='${vault}'
    exec \$SHELL -l
  "
}
