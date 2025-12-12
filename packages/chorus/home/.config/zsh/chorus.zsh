# chorus

bconf() {
  local dir=$CONFIG_DIR/chorus/bases.d file="." ext="yml"
  load_conf $1 $2
}

rconf() {
  local dir=$CONFIG_DIR/chorus/repos.d file="." ext="yml"
  load_conf $1 $2
}

sconf() {
  local dir=$CONFIG_DIR/chorus/spaces.d file="." ext="yml"
  load_conf $1 $2
}

vault_path() {
  local vault="$1"
  vault ls | grep "^$vault:" | awk -F': ' '{print $2}'
}

vcd() {
  local vault="$1"
  local path=$(vault_path "$vault")
  
  if [[ -z "$path" ]]; then
    echo "Vault '$vault' not found"
    return 1
  fi
  
  cd "$path"
}

alias bls="base list"
alias rls="repo list $1"
alias vls="vault list"
