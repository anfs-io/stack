# claude.zsh

# --- Claude Plugin Path ---
# Plugin search directories are defined in ~/.config/claude/plugins.d/.
# Each file contains one or more lines with directory paths to scan.
# Each directory is scanned for .claude-plugin/plugin.json manifests;
# the parent directory of each match is a loadable plugin root.

_claude_plugin_dirs() {
  local -a dirs=()
  local plugins_d="${XDG_CONFIG_HOME}/claude/plugins.d"
  [[ -d "$plugins_d" ]] || return

  for conf in "$plugins_d"/*(-.N); do
    while IFS= read -r search_path; do
      search_path="${search_path%%\#*}"   # strip comments
      search_path="${search_path// /}"   # trim whitespace
      [[ -z "$search_path" ]] && continue
      search_path="${(e)search_path}"    # expand ~ and $HOME
      [[ -d "$search_path" ]] || continue
      while IFS= read -r manifest; do
        dirs+=("${manifest:h:h}")
      done < <(find "$search_path" -name "plugin.json" -path "*/.claude-plugin/*" 2>/dev/null)
    done < "$conf"
  done
  print -l "${dirs[@]}"
}

# --- Shortcuts ---
_invoke_claude() {
  local verbose=false
  [[ "$1" == "--debug" ]] && { verbose=true; shift; }
  local -a flags=()
  for dir in $(_claude_plugin_dirs); do
    flags+=(--plugin-dir "$dir")
  done
  $verbose && echo "${flags[@]}" "$@"
  claude "${flags[@]}" "$@"
}

alias cc="clear; _invoke_claude $@"
alias cc-continue="clear; _invoke_claude --continue $@"
alias cc-yolo="clear; _invoke_claude --dangerously-skip-permissions $@"
alias cc-resume="clear; _invoke_claude --resume $@"
alias cc-version="claude --version"

cconf() {
  local dir=$HOME/.claude/context file="." ext="md"
  load_conf "$@"
}
