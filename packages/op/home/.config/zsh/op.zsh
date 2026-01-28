# 1password

# Load 1Password plugins if available
if [ -f $HOME/.config/op/plugins.sh ]; then
  source $HOME/.config/op/plugins.sh
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
