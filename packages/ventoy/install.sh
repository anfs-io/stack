# stack/ventoy - Ventoy USB boot manager (wrapper: ~/.local/bin/ventoy)
#
# Ventoy2Disk.sh only runs on Linux, so the release is only fetched there.
# On macOS the wrapper can still copy ISOs to an already-prepared stick.

VENTOY_VERSION="1.1.17"
VENTOY_SHA256="7fb4ed08cef6a6b4d39dd19260d8c80291a78dfdf9af7d461571e23cbbc43805"

install_linux() {
  local data="${XDG_DATA_HOME:-$HOME/.local/share}/ventoy"
  local release="$data/ventoy-$VENTOY_VERSION"

  if [[ ! -f "$release/Ventoy2Disk.sh" ]]; then
    local tarball
    tarball="$(mktemp)"
    curl -fsSL -o "$tarball" \
      "https://github.com/ventoy/Ventoy/releases/download/v$VENTOY_VERSION/ventoy-$VENTOY_VERSION-linux.tar.gz"
    if ! echo "$VENTOY_SHA256  $tarball" | sha256sum -c --quiet -; then
      rm -f "$tarball"
      echo "ventoy: checksum mismatch for ventoy-$VENTOY_VERSION-linux.tar.gz" >&2
      return 1
    fi
    mkdir -p "$data"
    tar -xzf "$tarball" -C "$data"
    rm -f "$tarball"
  fi

  ln -sfn "ventoy-$VENTOY_VERSION" "$data/current"
}

post_install() {
  user_message "Choose the ISOs for a stick with: ventoy get <id> (list them with: ventoy isos); they are downloaded once, into the store pim and pmm use too"
  user_message "For a PiKVM, use a disk image instead of a stick: ventoy prepare /srv/nfs/pikvm/ventoy.img (see: ventoy help)"
}

remove_linux() {
  rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/ventoy"
}
