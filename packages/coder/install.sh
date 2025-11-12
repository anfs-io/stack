# coder

pre_install() { return; }

install_linux() { return; }

install_macos() {
  [[ "${CODER_PROFILE}" != "local" ]] && return

  apps_string=$(cat $XDG_CONFIG_DIR/coder/brew.txt)
  IFS=$'\n' apps=($apps_string)
  # echo "apps: ${apps[@]}"

  set +e
  for app in "${apps[@]}"; do
    # Try cask first, then formula
    if brew info --cask "$app" &>/dev/null; then
      app_name=$(brew info --cask "$app" | grep "\.app (App)" | sed 's/ (App).*//')
      cask_result=$?
      if [[ $cask_result -eq 0 ]]; then
        if [[ -d "/Applications/$app_name" ]]; then
          echo "$app already installed"
        else
          brew install $app
        fi
        # echo "Got cask app_name: '$app_name'"
      elif brew info "$app" &>/dev/null; then
        brew install $app
        # echo "Formula (CLI tool): $app"
      fi
    else
      echo "Not found: $app"
    fi
    # echo "Got app_name: '$app_name'"
  done
  set -e
}

post_install() { return; }
