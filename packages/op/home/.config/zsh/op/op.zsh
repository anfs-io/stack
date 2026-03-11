# 1password - shared configuration (macOS and Linux)
#
# Env vars (set by mise via .mise.toml at space/area/project roots):
#   OP_SPACE — 1Password vault space component (falls back to CHORUS_SPACE)
#   OP_AREA  — 1Password vault area component (falls back to CHORUS_AREA)
#
# Env vars (injected by rssh on remote hosts):
#   OP_SERVICE_ACCOUNT_TOKEN — SA token for the active org
#   OP_SPACE                 — space component forwarded from Mac session
#   OP_AREA                  — area component forwarded from Mac session (if set)

# ---------------------------------------------------------------------------
# Context discovery
# ---------------------------------------------------------------------------
# These functions resolve the current space/area/vault context.
# Each prefers the OP-specific var, falls back to the CHORUS equivalent,
# and warns if neither is set. All other functions call these rather than
# reading env vars directly.

# Resolve the current space name.
_op_space() {
  local space="${OP_SPACE:-$CHORUS_SPACE}"
  if [[ -z "$space" ]]; then
    echo "Warning: No space context -- set OP_SPACE or CHORUS_SPACE (cd into a space directory)" >&2
    return 1
  fi
  echo "$space"
}

# Resolve the current area name (may be empty).
_op_area() {
  echo "${OP_AREA:-$CHORUS_AREA}"
}

# Build the 1Password vault name from space + optional area.
#
# Examples:
#   OP_SPACE=rjayroach                    -> rjayroach
#   OP_SPACE=lgat OP_AREA=marketing       -> lgat-marketing
#   CHORUS_SPACE=cnfs (no OP_SPACE set)   -> cnfs
_op_vault() {
  local space
  space=$(_op_space) || return 1

  local area
  area=$(_op_area)

  local vault="${space}"
  [[ -n "$area" ]] && vault="${vault}-${area}"
  echo "$vault"
}

# ---------------------------------------------------------------------------
# Credential loading
# ---------------------------------------------------------------------------
# Fetch a secret from 1Password. With one arg, echoes the value.
# With two args, exports the value into the named env var (lazy — skips
# if the var is already set).
#
# Usage:
#   _op_env <service/field>              # echo the value
#   _op_env <service/field> <VAR_NAME>   # export VAR_NAME=<value> (lazy)
#
# Examples:
#   _op_env github/token                 # prints the token
#   _op_env github/token GH_TOKEN        # exports GH_TOKEN (if unset)
#   curl -H "Authorization: token $(_op_env github/token)" ...
_op_env() {
  local ref="$1"
  local var="$2"

  # If var is given and already set, skip the fetch
  if [[ -n "$var" && -n "${(P)var}" ]]; then
    return 0
  fi

  local vault
  vault=$(_op_vault) || return 1

  # Works with both SA token (remote/CI) and desktop app auth (local Mac)
  local value
  value=$(op read "op://${vault}/${ref}" 2>/dev/null)
  if [[ -z "$value" ]]; then
    echo "Warning: Failed to read ${ref} from vault ${vault}" >&2
    return 1
  fi

  if [[ -n "$var" ]]; then
    export "$var"="$value"
  else
    echo "$value"
  fi
}

# ---------------------------------------------------------------------------
# Tool wrappers (lazy credential loading via Service Account)
# ---------------------------------------------------------------------------
# These activate only on remote hosts where OP_SERVICE_ACCOUNT_TOKEN is set.
# Each wrapper lazily fetches credentials on first invocation, then caches
# in the env var for the remainder of the session.

if [[ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]]; then
  gh() {
    _op_env github/token GH_TOKEN
    command gh "$@"
  }

  aws() {
    _op_env aws/access-key-id AWS_ACCESS_KEY_ID
    _op_env aws/secret-access-key AWS_SECRET_ACCESS_KEY
    command aws "$@"
  }

  # Add more tool wrappers here as needed, e.g.:
  # gcloud() {
  #   _op_env gcp/access-token CLOUDSDK_AUTH_ACCESS_TOKEN
  #   command gcloud "$@"
  # }
fi

