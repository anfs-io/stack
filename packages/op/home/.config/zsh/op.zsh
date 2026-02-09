# 1password

# Load 1Password plugins if available
if [ -f $HOME/.config/op/plugins.sh ]; then
  source $HOME/.config/op/plugins.sh
fi

ssho() {
  local op_string="rjayroach/Service Account Auth Token Testing/credential"
  local op_sa_token=$(op read "op://$op_string")
  ssh -t "$@" "
    export OP_SERVICE_ACCOUNT_TOKEN='$op_sa_token'
    exec \$SHELL -l
  "
}

if [ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
  local op_string="Service Account Testing/GitHub Personal Access Token - Test 1/token"
  export GH_TOKEN=$(op read 'op://DevCreds/GitHub CLI Token/credential')
  # add others as needed
fi


# opcreds CLI alias
if [ -x "$HOME/.local/bin/opcreds" ]; then
  alias opc='opcreds'
  
  # Quick access functions
  opget() {
    opcreds get "$@"
  }
  
  opnew() {
    opcreds create "$@"
  }
  
  opls() {
    opcreds list "$@"
  }
fi

# Environment injection helper
# Usage: openv "op://vault/item/field" VAR_NAME
openv() {
  local ref="$1"
  local var_name="${2:-$(basename "$ref" | tr '[:lower:]' '[:upper:]' | tr ' -' '_')}"
  export "$var_name"="$(op read "$ref")"
}

# Load secrets from a template file into environment
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
