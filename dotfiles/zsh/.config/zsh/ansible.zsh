# custom aliases

export ANSIBLE_VAULT_PASSWORD_FILE="./secrets.pwd"

alias ave="ansible-vault edit secrets.enc"
alias avv="ansible-vault view secrets.enc"

avc() {
  if [ ! -f secrets.pwd ]; then
    echo "\nsecrets.pwd" >> .gitignore
    bip39 >> secrets.pwd
  fi
  if [ ! -f secrets.enc ]; then
    ansible-vault create secrets.enc
  else
    ansible-vault edit secrets.enc
  fi
}
