# claude.zsh
CLAUDE_PLUGIN_PATH="$HOME/spaces/anfs/technical/marketplace/plugins:$HOME/spaces/anfs/technical/third/plugins"

# --- Claude Plugin Path ---
# Colon-separated list of directories containing Claude Code plugins.
# Each directory is scanned for plugin.json manifests, and matching
# plugins are loaded via --plugin-dir flags.

# Parse CLAUDE_PLUGIN_PATH into an array of plugin directories.
# Each entry in the path is scanned for .claude-plugin/plugin.json files;
# the parent directory of each match is a loadable plugin root.
_claude_plugin_dirs() {
  local -a dirs=()
  local IFS=':'
  for search_path in $=CLAUDE_PLUGIN_PATH; do
    [[ -d "$search_path" ]] || continue
    while IFS= read -r manifest; do
      local plugin_dir="${manifest:h:h}"
      dirs+=("$plugin_dir")
    done < <(find "$search_path" -name "plugin.json" -path "*/.claude-plugin/*" 2>/dev/null)
  done
  print -l "${dirs[@]}"
}

# --- Shortcuts ---
cc() {
  clear
  local -a flags=()
  for dir in $(_claude_plugin_dirs); do
    flags+=(--plugin-dir "$dir")
  done
  # echo "${flags[@]}" "$@"
  claude "${flags[@]}" "$@"
}

alias cc-continue="clear; cc --continue"
alias cc-yolo="clear; cc --dangerously-skip-permissions $@"
alias cc-resume="clear; cc --resume"
alias cc-version="claude --version"

cconf() {
  local dir=$HOME/.claude/context file="." ext="md"
  load_conf "$@"
}
