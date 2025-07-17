# custom aliases

export ANSIBLE_VAULT_PASSWORD_FILE="./secrets.pwd"

_ensure_secrets() {
  local file="$1"
  if [ ! -f secrets.pwd ]; then
    echo "\nsecrets.pwd" >> .gitignore
    bip39 >> secrets.pwd
  fi
  if [ ! -f "$file" ]; then
    echo "" > "$file"
    ansible-vault encrypt "$file"
  fi
}

ave() {
  local file="${1:-secrets.enc}"
  _ensure_secrets "$file"
  ansible-vault edit "$file"
}

avv() {
  local file="${1:-secrets.enc}"
  _ensure_secrets "$file"
  ansible-vault view "$file"
}
