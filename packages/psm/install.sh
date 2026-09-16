# psm
#
# Installs psm (~/.local/bin/psm), which syncs the agent skills declared in
# ~/.config/psm/*.yml to every AI agent ppm has installed. The sync logic
# lives in psm so skills can be refreshed without reinstalling: see `psm help`.

# --- marketplace plugin cloning: parked until the skills CLI work settles ---
# PLUGINS_DIR="$XDG_CACHE_HOME/agents/plugins"
#
# REPOS=(
#   "git@github.com:rjayroach/marketplace.git"
#   "git@github.com:cnfs-io/marketplace.git"
#   "git@github.com:anfs-io/marketplace.git"
# )
#
# x_install() {
#   mkdir -p "$PLUGINS_DIR"
#
#   for url in "${REPOS[@]}"; do
#     local owner="${url#*:}"
#     owner="${owner%%/*}"
#     local target="$PLUGINS_DIR/$owner"
#
#     if [[ -d "$target/.git" ]]; then
#       user_message "Pulled $owner into $target"
#       git -C "$target" pull --quiet
#     else
#       user_message "Cloned $owner into $target"
#       git clone --quiet "$url" "$target"
#     fi
#   done
# }

pre_install() {
  local cyan='\033[0;36m' nc='\033[0m'
  echo -e "${cyan}"
  cat << "EOF"
 ____  ____  __  __
|  _ \/ ___||  \/  |
| |_) \___ \| |\/| |
|  __/ ___) | |  | |
|_|   |____/|_|  |_|

EOF
  echo -e "${cyan}Personal Skills Manager${nc}"
}

post_install() {
  psm sync || ppm_fail "psm sync reported failures — fix and re-run: psm sync" || true
}

post_remove() {
  user_message "Installed skills were left in place — list them with: npx skills list -g"
}
