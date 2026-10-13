# op

# The service account token reaches a remote host as an environment variable carried by the
# SSH protocol: `ssh -o SendEnv=OP_SERVICE_ACCOUNT_TOKEN`, sent by the ssh hook this package
# installs. sshd discards any variable it has not been told to accept, and says nothing when it
# does — a host missing this looks exactly like "no secrets configured" — so the matching
# AcceptEnv is written here.
#
# /etc/ssh is root-owned, so this cannot be stowed. Same shape as stack/bash registering brew's
# bash in /etc/shells, and handled the same way: grep first so a settled host never prompts,
# _system_sudo to prime the credential cache, then `sudo -n` so an unattended install cannot block.
#
# Not gated on the OS. macOS ships sshd with Include /etc/ssh/sshd_config.d/* too, and a Mac can
# be the host you ssh into; gating on "linux" would encode one person's workflow rather than a
# real platform difference. It is gated on sshd actually running, so a machine that is only ever
# an ssh client is left alone and never prompts for sudo.
_OP_SSHD_DROPIN=/etc/ssh/sshd_config.d/50-ppm-op.conf
_OP_ACCEPT_ENV='AcceptEnv OP_SERVICE_ACCOUNT_TOKEN'

post_install() {
  _op_sshd_accept_env
}

# This host answers ssh, so the AcceptEnv is worth writing.
_op_sshd_is_server() {
  command -v sshd >/dev/null 2>&1 || return 1
  pgrep -x sshd >/dev/null 2>&1 && return 0
  systemctl is-enabled --quiet ssh 2>/dev/null && return 0
  systemctl is-enabled --quiet sshd 2>/dev/null && return 0
  return 1
}

_op_sshd_accept_env() {
  [[ -n "${PPM_OP_SKIP_SSHD:-}" ]] && return 0
  _op_sshd_is_server || return 0

  # Settled: no sudo, no prompt, no reload.
  grep -qxF "$_OP_ACCEPT_ENV" "$_OP_SSHD_DROPIN" 2>/dev/null && return 0

  # Debian 11 and older ship no Include line, so a drop-in would sit there doing nothing.
  # Say so rather than writing a file that silently has no effect.
  if ! grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' /etc/ssh/sshd_config 2>/dev/null; then
    user_message "This sshd does not Include /etc/ssh/sshd_config.d/.\nAdd to /etc/ssh/sshd_config by hand:\n  $_OP_ACCEPT_ENV\nthen: sudo sshd -t && sudo systemctl reload ssh"
    return 0
  fi

  if ! _system_sudo "$_OP_ACCEPT_ENV" \
      "Forwarding the 1Password service account token needs sudo. Run:\n  printf '%s\\n' '$_OP_ACCEPT_ENV' | sudo tee $_OP_SSHD_DROPIN\n  sudo sshd -t && sudo systemctl reload ssh"
  then
    return 0
  fi

  printf '# ppm stack/op: accept the service account token forwarded by the ssh hook\n%s\n' "$_OP_ACCEPT_ENV" \
    | sudo -n tee "$_OP_SSHD_DROPIN" >/dev/null || { user_message "Could not write $_OP_SSHD_DROPIN"; return 0; }
  sudo -n chmod 0644 "$_OP_SSHD_DROPIN" 2>/dev/null

  # Validate before reloading. This host is quite possibly only reachable over ssh, so a drop-in
  # that fails validation must not be left where the next sshd restart would find it.
  if ! sudo -n sshd -t 2>/dev/null; then
    sudo -n rm -f "$_OP_SSHD_DROPIN"
    user_message "sshd rejected $_OP_SSHD_DROPIN; reverted, nothing changed"
    return 0
  fi

  # reload, not restart: established sessions — including the one running this — survive.
  sudo -n systemctl reload ssh 2>/dev/null \
    || sudo -n systemctl reload sshd 2>/dev/null \
    || user_message "Wrote $_OP_SSHD_DROPIN. Reload sshd to apply it: sudo systemctl reload ssh"
}

# Root-owned and machine-wide, so it is left in place and explained rather than removed silently —
# the same call stack/bash makes about its /etc/shells line.
post_remove() {
  [[ -f "$_OP_SSHD_DROPIN" ]] || return 0
  user_message "Left $_OP_SSHD_DROPIN in place.\nTo remove it: sudo rm $_OP_SSHD_DROPIN && sudo systemctl reload ssh"
}

# --- anfs onboard (the contract: core/ppm's lib/ppm/onboard.sh) ---------------------------------
#   pm          the CLI connected to your account, and the vault that holds your credentials
#   pm-key      an ssh key kept in that vault: found, or created with --key op
#   pm-github   gh's token kept in that vault, and gh told to read it from there

_OP_GH_ITEM=github   # the item; the token is its field `token` (op://<vault>/github/token)

# Signed in: a service account token, or an account the desktop app shares with the CLI
_op_ready() {
  [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]] || [[ -n "$(op account list 2>/dev/null || true)" ]]
}

# The vault a previous run chose, read back from the token reference it wrote
_op_vault_from_fnox() {
  local file="$XDG_CONFIG_HOME/fnox/gh.toml"
  [[ -f "$file" ]] || return 0
  sed -n 's|.*"op://\([^/"]*\)/.*|\1|p' "$file" | head -n 1
}

onboard_pm_detect() {
  local vault
  command -v op >/dev/null 2>&1 || { onboard_detail "op is not on PATH (open a new shell)"; return 1; }
  if ! _op_ready; then
    if [[ "$(os)" != macos ]]; then
      onboard_state skip
      onboard_detail "op signs in here with a service account: set OP_SERVICE_ACCOUNT_TOKEN (opm create <name>, on your own machine)"
      return 0
    fi
    onboard_detail "the 1Password CLI is not connected to the app"
    return 1
  fi
  vault=$(onboard_opt vault)
  [[ -n "$vault" ]] || vault=$(_op_vault_from_fnox)
  [[ -n "$vault" ]] || { onboard_detail "1Password: no vault chosen (--vault)"; return 1; }
  onboard_set pm op
  onboard_set vault "$vault"
  onboard_detail "1Password, vault $vault"
}

onboard_pm() {
  local -a vaults=()
  ! onboard_pm_detect || return 0
  command -v op >/dev/null 2>&1 || return 1

  while ! _op_ready; do
    cat <<'MSG'
The 1Password CLI is not connected to the app. In 1Password, open Settings > Developer and turn on
  - Integrate with 1Password CLI
  - Use the SSH agent
MSG
    ! onboard_yes || anfs_die "the 1Password CLI is not signed in"
    onboard_propose "Done; check again" || return 1
  done

  if [[ -z "$(onboard_opt vault)" ]]; then
    # Which vault holds your credentials is yours to say, never the first one found
    if onboard_yes || [[ ! -t 0 ]]; then
      echo "ppm: which vault holds your credentials? pass --vault" >&2
      exit 64
    fi
    mapfile -t vaults < <(op vault list --format json 2>/dev/null | yq -p json -r '.[].name' 2>/dev/null)
    [[ ${#vaults[@]} -gt 0 ]] || anfs_die "op lists no vaults (op vault list)"
    anfs_choose --vault "The vault for your GitHub token and ssh key" "${vaults[@]}"
    onboard_set opt.vault "$REPLY"
  fi
  onboard_pm_detect
}

_op_key_find() {
  local vault="$1" id
  id=$(op item list --categories "SSH Key" --vault "$vault" --format json 2>/dev/null |
    yq -p json -r '.[0].id // ""' 2>/dev/null || true)
  [[ -n "$id" ]] || return 0
  op read "op://$vault/$id/public key" 2>/dev/null || true
}

onboard_pm_key_detect() {
  local vault kind pubkey
  vault=$(onboard_get vault) kind=$(onboard_opt key)
  if [[ -z "$vault" ]]; then
    onboard_state n/a
    onboard_detail "1Password is not set up (the pm step)"
    return 0
  fi
  if [[ -n "$kind" && "$kind" != op ]]; then
    onboard_state n/a
    onboard_detail "--key $kind"
    return 0
  fi
  pubkey=$(_op_key_find "$vault")
  if [[ -n "$pubkey" ]]; then
    onboard_set pubkey "$pubkey"
    onboard_set key_source 1Password
    onboard_detail "an ssh key is in $vault"
    return 0
  fi
  [[ "$kind" == op ]] || onboard_state optional
  onboard_detail "no ssh key in $vault (--key op creates one)"
  return 1
}

# A new key is made only when asked for: --key op, or a yes to the question
onboard_pm_key() {
  local vault
  ! onboard_pm_key_detect || return 0
  vault=$(onboard_get vault)
  [[ "$(onboard_opt key)" == op ]] ||
    onboard_confirm "Create an ssh key in 1Password ($vault); the private key never leaves it" || return 1
  op item create --category "SSH Key" --title "ssh key ($(id -un))" --vault "$vault" \
    --ssh-generate-key ed25519 >/dev/null || anfs_die "op could not create the ssh key"
  onboard_pm_key_detect
}

_op_gh_item_exists() { op item get "$_OP_GH_ITEM" --vault "$1" >/dev/null 2>&1; }

onboard_pm_github_detect() {
  local vault
  vault=$(onboard_get vault)
  if [[ -z "$vault" ]]; then
    onboard_state n/a
    onboard_detail "1Password is not set up (the pm step)"
    return 0
  fi
  if ! command -v gh >/dev/null 2>&1; then
    onboard_state n/a
    onboard_detail "gh is not installed"
    return 0
  fi
  if ! _op_gh_item_exists "$vault"; then
    if ! gh auth token >/dev/null 2>&1; then
      onboard_state n/a
      onboard_detail "not signed in to GitHub yet (the github step)"
      return 0
    fi
    onboard_detail "your GitHub token is not in 1Password"
    return 1
  fi
  if [[ ! -e "$XDG_CONFIG_HOME/fnox/gh.toml" ]]; then
    onboard_detail "gh is not told to read its token from 1Password"
    return 1
  fi
  onboard_detail "gh reads its token from $vault/$_OP_GH_ITEM"
}

onboard_pm_github() {
  local vault token dir ref file
  ! onboard_pm_github_detect || return 0
  vault=$(onboard_get vault)
  [[ -n "$vault" ]] || return 0

  if ! _op_gh_item_exists "$vault"; then
    token=$(gh auth token 2>/dev/null) || return 1
    onboard_propose "Keep your GitHub token in 1Password ($vault/$_OP_GH_ITEM)" || return 1
    # On stdin, as an item template: an argument would show in the process list
    printf '{"title":"%s","category":"API_CREDENTIAL","fields":[{"id":"token","label":"token","type":"CONCEALED","value":"%s"}]}\n' \
      "$_OP_GH_ITEM" "$token" | op item create --vault "$vault" - >/dev/null ||
      { ppm_fail "op could not save the token; gh keeps its own copy"; return 1; }
    # gh's own copy is now a second one. Dropping it is offered, never assumed.
    if onboard_confirm "Remove gh's own copy of the token, so 1Password is the only place it lives"; then
      gh auth logout --hostname github.com >/dev/null 2>&1 || true
    fi
  fi

  # What stack/git's gh wrapper reads. In your repo when you have one, so every machine gets it.
  if [[ ! -e "$XDG_CONFIG_HOME/fnox/gh.toml" ]]; then
    ref="op://$vault/$_OP_GH_ITEM/token"
    dir=$(onboard_user_repo)
    if [[ -n "$dir" ]]; then
      file="$dir/packages/op/home/.config/fnox/gh.toml"
      [[ -f "$dir/packages/op/package.yml" ]] ||
        { mkdir -p "$dir/packages/op"; printf 'version: 0.1.0\nauthor: %s\n' "$(id -un)" > "$dir/packages/op/package.yml"; }
    else
      file="$XDG_CONFIG_HOME/fnox/gh.toml"
    fi
    mkdir -p "${file%/*}"
    cat > "$file" <<TOML
default_provider = "onepass"

[providers.onepass]
type = "1password"

[secrets]
GH_TOKEN = { value = "$ref" }
GH_AUTH_TOKEN = { value = "$ref" }
TOML
    if [[ -n "$dir" ]]; then
      "$BIN_DIR/ppm" install "$PPM_USER_REPO_ALIAS/op" ||
        ppm_fail "ppm install $PPM_USER_REPO_ALIAS/op failed; the file is $file"
      onboard_commit "$dir" "op: gh reads its token from 1Password"
    fi
  fi
  onboard_pm_github_detect
}
