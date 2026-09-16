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

PSM_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/psm"

# Write a fully commented example so a fresh machine has something to edit.
_seed_config() {
  local file

  for file in "$PSM_CONFIG_HOME"/*.yml "$PSM_CONFIG_HOME"/*.yaml; do
    [[ -f "$file" ]] && return 0
  done

  cat > "$PSM_CONFIG_HOME/example.yml" <<'EOF'
# Agent skills synced by `psm sync`.
#
# Drop any number of *.yml files in this directory. Each declares a `sources:`
# list; every entry is installed for each AI agent ppm has installed (any
# package whose package.yml carries an `agent:` key).
#
# Skills that ppm packages stow into ~/.local/share/psm/skills need no entry
# here: psm syncs that directory as the `builtin` repo.
#
# sources:
#   - repo: DietrichGebert/ponytail
#     skills:
#       - ponytail
#       - ponytail-audit
#
#   - repo: obra/superpowers
#     skills: ["*"]           # every skill in the repo
#     agents: [claude-code]   # optional: install only for these agents
#
# `repo` accepts anything the skills CLI does: owner/repo, a full GitHub or
# GitLab URL, a git@ URL, a tree/main/skills/<name> subpath, or a local path.
# A leading ~ in a local path is expanded to your home directory. Local skills
# are copied, so run `psm update` after editing them.
#
#   - repo: ~/src/my-skills
#     skills: ["*"]
EOF

  user_message "Created $PSM_CONFIG_HOME/example.yml — add sources there, then run: psm sync"
}

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
  mkdir -p "$PSM_CONFIG_HOME"
  _seed_config
  psm sync || ppm_fail "psm sync reported failures — fix and re-run: psm sync" || true
}

post_remove() {
  user_message "Installed skills were left in place — list them with: npx skills list -g"
}
