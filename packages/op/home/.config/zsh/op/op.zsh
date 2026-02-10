# 1password - shared configuration (macOS and Linux)

# ─────────────────────────────────────────────────────────────────────────────
# Lazy credential loading
# ─────────────────────────────────────────────────────────────────────────────
# Generic helper to lazily load an env var from 1Password.
# Usage: _op_env <VAR_NAME> <item/field>
#   VAR_NAME:   The environment variable to set
#   item_field: The item/field path appended to op://$OP_VAULT/
_op_env() {
  local var="$1"
  local ref="$2"

  if [[ -n "$OP_SERVICE_ACCOUNT_TOKEN" && -z "${(P)var}" ]]; then
    export "$var"=$(op read "op://${OP_VAULT}/${ref}" 2>/dev/null)
    if [[ -z "${(P)var}" ]]; then
      echo "Warning: Failed to read ${ref} from vault ${OP_VAULT}" >&2
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Tool wrappers (lazy credential loading via Service Account)
# ─────────────────────────────────────────────────────────────────────────────

if [[ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]]; then
  gh() {
    _op_env GH_TOKEN 'GitHub CLI Token/credential'
    command gh "$@"
  }

  aws() {
    _op_env AWS_ACCESS_KEY_ID 'AWS/access key id'
    _op_env AWS_SECRET_ACCESS_KEY 'AWS/secret access key'
    command aws "$@"
  }

  # Add more tool wrappers here as needed, e.g.:
  # gcloud() {
  #   _op_env GOOGLE_APPLICATION_CREDENTIALS_JSON 'GCP/credential'
  #   command gcloud "$@"
  # }
fi

# ─────────────────────────────────────────────────────────────────────────────
# opcreds CLI integration
# ─────────────────────────────────────────────────────────────────────────────

if [ -x "$HOME/.local/bin/opcreds" ]; then
  alias opc='opcreds'

  opget() { opcreds get "$@"; }
  opnew() { opcreds create "$@"; }
  opls()  { opcreds list "$@"; }
fi

# ─────────────────────────────────────────────────────────────────────────────
# Environment injection helpers
# ─────────────────────────────────────────────────────────────────────────────

# Load a single secret into an environment variable
# Usage: openv "op://vault/item/field" VAR_NAME
openv() {
  local ref="$1"
  local var_name="${2:-$(basename "$ref" | tr '[:lower:]' '[:upper:]' | tr ' -' '_')}"
  export "$var_name"="$(op read "$ref")"
}

# Inject secrets from a template file into environment
# Usage: opsource .env.op
opsource() {
  local file="${1:-.env.op}"
  if [ -f "$file" ]; then
    eval "$(op inject -i "$file")"
  else
    echo "File not found: $file" >&2
    return 1
  fi
}
