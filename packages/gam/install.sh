# pde/gam
#
# Google Workspace administration via GAM7
# Uses mise pipx backend (with uv) to manage the gam7 Python package

GAM7_CONFIG_DIR="$XDG_CONFIG_HOME/gam7"
GAM7_WORK_DIR="$XDG_DATA_HOME/gam7"

dependencies() {
  echo "python"
}

post_install() {
  source <(mise activate bash)
  mise install pipx:gam7
  mise_fix_gam7

  # Refresh PATH so the newly-installed gam binary is found
  eval "$(mise env)"

  mkdir -p "$GAM7_CONFIG_DIR"
  mkdir -p "$GAM7_WORK_DIR"

  GAMCFGDIR="$GAM7_CONFIG_DIR" gam config drive_dir "$GAM7_WORK_DIR" verify
}

# Fix uv installer symlink bug (binaries end up one level deeper than mise expects)
mise_fix_gam7() {
  local bin_path=$(mise bin-paths | grep gam7)
  local gam_bin="${bin_path}/../gam7/bin"
  ln -sf "${gam_bin}/gam" "${bin_path}/gam"
}

post_remove() {
  mise uninstall pipx:gam7

  if $force; then
    rm -rf "$GAM7_CONFIG_DIR"
    rm -rf "$GAM7_WORK_DIR"
  fi
}
