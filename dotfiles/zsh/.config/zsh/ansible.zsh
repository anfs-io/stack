# Ansible shell functions

pcs_ansible_vault_password_file() {
  echo "./ansible-vault.key"
}

_ensure_vault_setup() {
  local vault_password_file="$(pcs_ansible_vault_password_file)"
  local vault_filename="$(basename "$vault_password_file")"

  # Create vault password file if it doesn't exist
  if [ ! -f "$vault_password_file" ]; then
    bip39 >> "$vault_password_file"
  fi

  # Ensure vault password file is in .gitignore
  if [ ! -f .gitignore ] || ! grep -q "^$vault_filename$" .gitignore; then
    echo "$vault_filename" >> .gitignore
  fi
}

avd() {
  local file="${1:-secrets.enc}"
  _ensure_vault_setup
  ansible-vault decrypt "$file" --vault-password-file="$(pcs_ansible_vault_password_file)"
}

ave() {
  local file="${1:-secrets.enc}"
  _ensure_vault_setup

  # Create file if it doesn't exist
  if [ ! -f "$file" ]; then
    touch "$file"
  fi

  # Try to edit the file, if it fails because it's not encrypted, encrypt it first
  if ! ansible-vault edit "$file" --vault-password-file="$(pcs_ansible_vault_password_file)" 2>/dev/null; then
    ansible-vault encrypt "$file" --vault-password-file="$(pcs_ansible_vault_password_file)"
    if [ $? -eq 0 ]; then
      ansible-vault edit "$file" --vault-password-file="$(pcs_ansible_vault_password_file)"
    fi
  fi
}

avv() {
  local file="${1:-secrets.enc}"
  _ensure_vault_setup
  ansible-vault view "$file" --vault-password-file="$(pcs_ansible_vault_password_file)"
}
