# 1password - macOS specific
#
# Provides:
#   - SA token caching in macOS Keychain (keyed by vault name)
#   - rssh: SSH to remote hosts with SA token + context injection
#   - op_create_vault: create a 1Password vault for a space/area
#   - op_setup_sa: create SA + store token for a vault
#   - op_setup_space: one-shot vault + SA + token creation
#
# Requires:
#   OP_SA_CREDENTIALS_VAULT — vault containing SA token items (e.g. "Private")
#   OP_SPACE / CHORUS_SPACE — active space (set by mise)

# ---------------------------------------------------------------------------
# Service Account Token Caching (macOS Keychain)
# ---------------------------------------------------------------------------
# Cache 1Password service account tokens in macOS Keychain so they don't
# require an `op read` call on every SSH session. Tokens are keyed by
# vault name (e.g., rjayroach, lgat, lgat-marketing).
#
# SA token items in 1Password are named: {vault}-sa-token
# e.g. op://Private/rjayroach-sa-token/credential
#      op://Private/lgat-marketing-sa-token/credential

# Store or retrieve a cached SA token for a given vault.
# Usage: _op_sa_token <vault>
#   vault: The vault name (used as keychain key and to derive token item name)
_op_sa_token() {
  local vault="$1"
  local keychain_key="op-sa-token-${vault}"
  local token

  if [[ -z "$OP_SA_CREDENTIALS_VAULT" ]]; then
    echo "Error: OP_SA_CREDENTIALS_VAULT is not set" >&2
    return 1
  fi

  # Try keychain first
  token=$(security find-generic-password -a "$USER" -s "$keychain_key" -w 2>/dev/null)

  if [[ -z "$token" ]]; then
    # Not cached -- fetch from 1Password and cache it
    local op_ref="op://${OP_SA_CREDENTIALS_VAULT}/${vault}-sa-token/credential"
    token=$(op read "$op_ref" 2>/dev/null)
    if [[ -z "$token" ]]; then
      echo "Error: Failed to read SA token for '${vault}' from ${op_ref}" >&2
      return 1
    fi
    security add-generic-password -a "$USER" -s "$keychain_key" -w "$token" 2>/dev/null
  fi

  echo "$token"
}

# Remove a cached SA token from keychain.
# Usage: _op_sa_token_clear <vault>
_op_sa_token_clear() {
  local vault="$1"
  if [[ -z "$vault" ]]; then
    echo "Usage: _op_sa_token_clear <vault>" >&2
    return 1
  fi
  local keychain_key="op-sa-token-${vault}"
  security delete-generic-password -a "$USER" -s "$keychain_key" 2>/dev/null
  echo "Cleared cached SA token for '${vault}'"
}

# List all cached SA tokens in keychain.
_op_sa_token_list() {
  security dump-keychain 2>/dev/null | grep -B5 '"op-sa-token-' | grep '"svce"' | \
    sed 's/.*"svce"<blob>="op-sa-token-\(.*\)"/  \1/'
}

# ---------------------------------------------------------------------------
# Vault & Service Account Setup
# ---------------------------------------------------------------------------

# Create a 1Password vault for a space or space-area.
# Usage: op_create_vault <name>
#   name: The vault name (e.g. rjayroach, lgat, lgat-marketing)
op_create_vault() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: op_create_vault <name>  (e.g. rjayroach, lgat-marketing)" >&2
    return 1
  fi

  op vault create "$name" --format json
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create vault '${name}'" >&2
    return 1
  fi

  echo "Created vault '${name}'"
}

# Create a service account + store its token.
# Usage: op_setup_sa <name>
#   name: The space/vault name (e.g. rjayroach, lgat, lgat-marketing)
#
# Creates:
#   SA named "{name}-sa" with read access to vault "{name}"
#   Token item "{name}-sa-token" in $OP_SA_CREDENTIALS_VAULT
op_setup_sa() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: op_setup_sa <name>  (e.g. rjayroach, lgat)" >&2
    return 1
  fi

  if [[ -z "$OP_SA_CREDENTIALS_VAULT" ]]; then
    echo "Error: OP_SA_CREDENTIALS_VAULT is not set" >&2
    return 1
  fi

  local token
  token=$(op service-account create "${name}-sa" \
    --vault "${name}:read_items" \
    --format json | jq -r '.token')

  if [[ -z "$token" || "$token" == "null" ]]; then
    echo "Error: Failed to create service account '${name}-sa'" >&2
    return 1
  fi

  op item create --category=api_credential \
    --title="${name}-sa-token" \
    --vault="${OP_SA_CREDENTIALS_VAULT}" \
    "credential=${token}"

  echo "Created SA '${name}-sa' with token stored as '${name}-sa-token' in ${OP_SA_CREDENTIALS_VAULT} vault"
}

# Create vault + SA + token in one shot.
# Usage: op_setup_space <name>
#   name: The space/vault name (e.g. rjayroach, lgat, lgat-marketing)
#
# Creates:
#   1. Vault "{name}"
#   2. SA "{name}-sa" with read access to that vault
#   3. Token item "{name}-sa-token" in $OP_SA_CREDENTIALS_VAULT
op_setup_space() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: op_setup_space <name>  (e.g. rjayroach, lgat)" >&2
    return 1
  fi

  op_create_vault "$name" || return 1
  op_setup_sa "$name" || return 1

  echo "Space '${name}' fully provisioned: vault + SA + token"
}

# ---------------------------------------------------------------------------
# Remote SSH with 1Password Service Account
# ---------------------------------------------------------------------------
# SSH to a remote host, injecting the service account token and space/area
# context into the remote session.
#
# The vault is determined by _op_vault() which reads:
#   OP_SPACE (or CHORUS_SPACE) + OP_AREA (or CHORUS_AREA) if set
#
# These are set automatically by mise when you're in a space directory.
# Override with: OP_SPACE=lgat OP_AREA=marketing rssh myhost
#
# On the remote host:
#   OP_SERVICE_ACCOUNT_TOKEN = SA token for the vault
#   OP_SPACE                 = space component
#   OP_AREA                  = area component (if set)

rssh() {
  local vault
  vault=$(_op_vault) || return 1

  local op_sa_token
  op_sa_token=$(_op_sa_token "$vault")
  if [[ $? -ne 0 ]]; then
    echo "Error: Could not retrieve SA token for vault '${vault}'" >&2
    return 1
  fi

  local space
  space=$(_op_space) || return 1
  local area
  area=$(_op_area)

  ssh -t "$@" "
    export OP_SERVICE_ACCOUNT_TOKEN='${op_sa_token}'
    export OP_SPACE='${space}'
    ${area:+export OP_AREA='${area}'}
    exec \$SHELL -l
  "
}
