# ghostty

# Change terminal background color (OSC 11)
function set_bg() {
  printf '\e]11;%s\e\\' "$1"
}

# Change terminal foreground color (OSC 10)
function set_fg() {
  printf '\e]10;%s\e\\' "$1"
}

# Reset colors to default (OSC 110/111)
function reset_colors() {
  printf '\e]110\e\\'  # Reset foreground
  printf '\e]111\e\\'  # Reset background
}

# Set tab/window title (OSC 2)
function tab_title() {
  printf '\e]2;%s\e\\' "$1"
}

# ssh with per-host background color + tab title theming.
#
# Host → color/title rules are externalized to a profiles file so you can
# customize them without editing this function. See sshg-profiles.conf.
# Override the path with $GHOSTTY_SSHG_PROFILES.
function sshg() {
  emulate -L zsh
  setopt extended_glob

  local host="${@: -1}"  # last argument is the host
  local profiles="${GHOSTTY_SSHG_PROFILES:-${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/sshg-profiles.conf}"

  # Defaults if no profile matches (preserves the original "other servers" look)
  local bg='#001a33'
  local title='🖥 %h'
  local hl="${host:l}"  # lowercase for case-insensitive matching

  if [[ -r "$profiles" ]]; then
    local pattern color label
    while IFS='|' read -r pattern color label; do
      # trim surrounding whitespace from each field
      pattern="${${pattern##[[:space:]]#}%%[[:space:]]#}"
      [[ -z "$pattern" || "$pattern" == '#'* ]] && continue
      color="${${color##[[:space:]]#}%%[[:space:]]#}"
      label="${${label##[[:space:]]#}%%[[:space:]]#}"
      if [[ "$hl" == ${~pattern} ]]; then
        [[ -n "$color" ]] && bg="$color"
        [[ -n "$label" ]] && title="$label"
        break
      fi
    done < "$profiles"
  fi

  set_bg "$bg"
  tab_title "${title//\%h/$host}"

  # Use the (unqualified) ssh so Ghostty's ssh-terminfo/ssh-env wrapper runs and
  # installs terminfo on the remote automatically. Do NOT use `command ssh` here
  # — that bypasses the wrapper and reintroduces broken xterm-ghostty displays.
  ssh "$@"

  # Reset when connection closes
  reset_colors
  tab_title "${PWD##*/}"
}

# fzf `sshg **<TAB>` completion: reuse fzf's built-in ssh host picker.
# Defined unconditionally and resolved at completion time, so it works whether
# fzf's completion loads before or after this file.
_fzf_complete_sshg() {
  (( $+functions[_fzf_complete_ssh] )) && _fzf_complete_ssh "$@"
}
