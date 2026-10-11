# gam7.zsh - GAM7 Google Workspace CLI

# Config directory (gam.cfg, cache, and local fallback credentials)
export GAMCFGDIR="$HOME/.config/gam7"

# 1Password credential references (set to enable secure credential injection)
# When set, the gam wrapper pulls credentials from 1Password into temp files
# per invocation — nothing persists on disk beyond the process lifetime.
# export GAM7_OP_OAUTH2="op://Private/gam7-oauth2/credential"
# export GAM7_OP_OAUTH2SERVICE="op://Private/gam7-oauth2service/credential"
# export GAM7_OP_CLIENT_SECRETS="op://Private/gam7-client-secrets/credential"

# Wrapper: injects credentials from 1Password when configured, otherwise
# falls back to local files in GAMCFGDIR.
unalias gam 2>/dev/null
gam() {
  if command -v op >/dev/null 2>&1 \
    && [[ -n "$GAM7_OP_OAUTH2" ]] \
    && [[ -n "$GAM7_OP_OAUTH2SERVICE" ]] \
    && [[ -n "$GAM7_OP_CLIENT_SECRETS" ]]; then

    local tmpdir=$(mktemp -d)
    trap "rm -rf ${(q)tmpdir}" INT TERM

    if op read "$GAM7_OP_OAUTH2" > "$tmpdir/oauth2.txt" 2>/dev/null \
      && op read "$GAM7_OP_OAUTH2SERVICE" > "$tmpdir/oauth2service.json" 2>/dev/null \
      && op read "$GAM7_OP_CLIENT_SECRETS" > "$tmpdir/client_secrets.json" 2>/dev/null; then

      OAUTHFILE="$tmpdir/oauth2.txt" \
      OAUTHSERVICEFILE="$tmpdir/oauth2service.json" \
      CLIENTSECRETS="$tmpdir/client_secrets.json" \
      command gam "$@"
      local ret=$?

      rm -rf "$tmpdir"
      trap - INT TERM
      return $ret
    fi

    echo "gam7: 1Password credential injection failed, falling back to local credentials" >&2
    rm -rf "$tmpdir"
    trap - INT TERM
  fi

  command gam "$@"
}

# Convenience aliases
alias gw="gam"
alias gwi="gam info domain"
alias gwu="gam info user"
alias gwul="gam print users"
alias gwgl="gam print groups"
