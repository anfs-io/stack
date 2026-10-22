# rails.zsh — the portable part is .config/sh/rails.sh

# omz's rails plugin aliases rp (plugin new) and rs (server); free the names
[[ -n "${aliases[rp]}" ]] && unalias rp
[[ -n "${aliases[rs]}" ]] && unalias rs
