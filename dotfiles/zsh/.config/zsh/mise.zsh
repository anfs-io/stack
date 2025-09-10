# mise

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

alias mra="mise run all"
alias mtd="mise trust ."
