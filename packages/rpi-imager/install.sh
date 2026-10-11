# utils/rpi-imager — write a Raspberry Pi card from a declarative cloud-init profile
#
# ppm installs the cask before hooks run, so this hook verifies the result rather than
# acting on it. A hand-installed app in /Applications makes the cask install fail, which
# is how a pre-2.0 copy survives `ppm install` — hence the explicit version gate.

RPI_IMAGER_APP="/Applications/Raspberry Pi Imager.app/Contents/MacOS/rpi-imager"

# Imager 2.0.2 and earlier accept --cloudinit-userdata and write nothing at all
RPI_IMAGER_MIN="2.0.3"

# True when $1 >= $2, comparing dotted numeric versions of any length
_rpi_version_ge() {
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | head -1)" == "$2" ]]
}

post_install() {
  [[ "$(os)" == "macos" ]] || return 0

  # The app is a convenience (GUI + image catalogue), not a requirement: rpi-imager
  # writes cards with dd because Imager's own --cli deadlocks on macOS. So a missing or
  # old app is worth mentioning, never worth failing the install over.
  if [[ ! -x "$RPI_IMAGER_APP" ]]; then
    user_message "Raspberry Pi Imager GUI not found (optional): brew install --cask raspberry-pi-imager"
    return
  fi

  # 2.x prints "Raspberry Pi Imager v2.0.11.1" on stdout with diagnostics on stderr;
  # 1.x printed "... version 1.8.5" on stderr with an empty stdout. Handle both.
  local version
  version="$("$RPI_IMAGER_APP" --version 2>/dev/null | grep -Eo 'v?[0-9]+(\.[0-9]+)+' | head -1)"
  [[ -n "$version" ]] || version="$("$RPI_IMAGER_APP" --version 2>&1 | grep -Eo 'v?[0-9]+(\.[0-9]+)+' | head -1)"
  version="${version#v}"

  if [[ -z "$version" ]]; then
    user_message "could not read the version of $RPI_IMAGER_APP"
    return
  fi

  if ! _rpi_version_ge "$version" "$RPI_IMAGER_MIN"; then
    user_message "Raspberry Pi Imager $version is old (>= $RPI_IMAGER_MIN recommended for the GUI)."
    user_message "  A hand-installed app blocks the cask; to let Homebrew own it:"
    user_message "    rm -rf '/Applications/Raspberry Pi Imager.app' && brew install --cask raspberry-pi-imager"
  fi

  user_message "Profiles live in ~/.config/rpi-imager/<name>/ — copy the example to start:"
  user_message "  cp -r ~/.config/rpi-imager/example ~/.config/rpi-imager/mypi"
  user_message "Then: rpi-imager list && rpi-imager show mypi && rpi-imager disks"
  user_message "Secrets come from the environment; a fnox.toml beside the profile is used automatically"
}

post_remove() {
  user_message "Your profiles in ~/.config/rpi-imager/ were left in place"
}
