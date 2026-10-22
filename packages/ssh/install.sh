# ssh

post_install() {
  if [[ -n "${PPM_SSH_AUTHORIZED_KEYS_URL:-}" && ! -f "$HOME/.ssh/authorized_keys" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    curl -fsSL -o "$HOME/.ssh/authorized_keys" "$PPM_SSH_AUTHORIZED_KEYS_URL"
    chmod 600 "$HOME/.ssh/authorized_keys"
  fi
  # A line in your own ~/.ssh/config, neither a link nor a copy (a package.yml's links: and files:
  # cannot say it): a candidate for a setup: key later
  add_to_file "$HOME/.ssh/config" "Include config.d/*.conf"
}

# --- anfs onboard (the contract: core/ppm's lib/ppm/onboard.sh) ---------------------------------
#   key      an ssh key to be you with: one another step found (1Password), one in ~/.ssh, one
#            your forwarded agent holds, or a new one here
#   access   in an ssh session: offer the agent's keys for this host's authorized_keys

_ssh_fingerprint() { ssh-keygen -lf /dev/stdin <<< "$1" 2>/dev/null | awk '{print $2}'; }

# The public key of one kind, or nothing: existing (in ~/.ssh, ed25519 first) or agent (the first
# the agent offers; without keys ssh-add fails and says so on stdout)
_ssh_key_find() {
  local file keys
  case "$1" in
    existing|local)
      for file in "$HOME/.ssh/id_ed25519.pub" "$HOME"/.ssh/*.pub; do
        [[ -f "$file" ]] || continue
        head -n 1 "$file"
        return 0
      done
      ;;
    agent)
      keys=$(ssh-add -L 2>/dev/null) || return 0
      head -n 1 <<< "$keys"
      ;;
  esac
}

onboard_key_detect() {
  local kind pubkey source k
  kind=$(onboard_opt key)
  case "$kind" in
    ""|agent|existing|local|op) ;;
    skip) onboard_state skip; onboard_detail "skipped (--key skip)"; return 0 ;;
    *) echo "ppm: --key is agent, existing, local, op or skip, not '$kind'" >&2; exit 64 ;;
  esac
  # A step before this one may hold the key already (stack/op: one kept in 1Password)
  pubkey=$(onboard_get pubkey) source=$(onboard_get key_source)
  if [[ -z "$pubkey" && "$kind" != op ]]; then
    for k in ${kind:-existing agent}; do
      pubkey=$(_ssh_key_find "$k")
      [[ -z "$pubkey" ]] || { source="$k"; break; }
    done
  fi
  if [[ -z "$pubkey" ]]; then
    onboard_detail "no ssh key${kind:+ ($kind)}"
    return 1
  fi
  onboard_set pubkey "$pubkey"
  onboard_set key_source "$source"
  onboard_detail "$(_ssh_fingerprint "$pubkey") ($source)"
}

onboard_key() {
  local kind file="$HOME/.ssh/id_ed25519"
  local -a args=()
  ! onboard_key_detect || return 0
  kind=$(onboard_opt key)
  if [[ -z "$kind" ]]; then
    onboard_choose key "No ssh key found" "local: create ${file/#$HOME/~}" "skip: none for now"
    kind="$REPLY"
  fi
  case "$kind" in
    local)
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      args=(-q -t ed25519 -f "$file" -C "$(id -un)@$(hostname -s)")
      # ssh-keygen asks for a passphrase itself; with nobody to ask there is none
      if onboard_yes || [[ ! -t 0 ]]; then args+=(-N ""); fi
      ssh-keygen "${args[@]}" || anfs_die "ssh-keygen failed"
      ;;
    skip)
      onboard_state skip
      onboard_detail "skipped"
      return 0
      ;;
    *)
      # agent, existing, op: there to be used, never made here
      return 1
      ;;
  esac
  onboard_key_detect
}

# The agent's keys this host does not accept yet, one per line. Only in an ssh session: that is
# when the agent is the one the person logged in from.
_ssh_access_new() {
  local auth="$HOME/.ssh/authorized_keys" keys line blob
  [[ -n "${SSH_CONNECTION:-}" ]] || return 0
  keys=$(ssh-add -L 2>/dev/null) || return 0
  while IFS= read -r line; do
    blob=$(awk '{print $2}' <<< "$line")
    [[ -n "$blob" ]] || continue
    if [[ -f "$auth" ]] && grep -qF -- "$blob" "$auth"; then continue; fi
    printf '%s\n' "$line"
  done <<< "$keys"
}

onboard_access_detect() {
  local new
  if [[ -z "${SSH_CONNECTION:-}" ]]; then
    onboard_state n/a
    onboard_detail "not an ssh session"
    return 0
  fi
  new=$(_ssh_access_new)
  if [[ -z "$new" ]]; then
    onboard_detail "no agent key to add to authorized_keys"
    return 0
  fi
  onboard_state optional
  onboard_detail "$(grep -c . <<< "$new") agent key(s) not in authorized_keys (--authorize)"
  return 1
}

# Never on -y alone: who may log in to this host is answered key by key, or named with --authorize
onboard_access() {
  local auth="$HOME/.ssh/authorized_keys" wanted new line fp add added=0
  ! onboard_access_detect || return 0
  wanted=$(onboard_opt authorize)
  wanted="${wanted// /$'\n'}"
  new=$(_ssh_access_new)

  while IFS= read -r -u 3 line; do
    [[ -n "$line" ]] || continue
    fp=$(_ssh_fingerprint "$line")
    add=false
    if [[ -n "$wanted" ]]; then
      if grep -qxF -e all -e "$fp" <<< "$wanted"; then add=true; fi
    elif onboard_confirm "Let $fp ($(awk '{print $1, $3}' <<< "$line")) log in to this host as $(id -un)"; then
      add=true
    fi
    $add || continue
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    printf '%s\n' "$line" >> "$auth"
    chmod 600 "$auth"
    added=$((added + 1))
  done 3<<< "$new"

  onboard_access_detect || true
  [[ $added -eq 0 ]] || onboard_detail "$added key(s) added to authorized_keys"
}
