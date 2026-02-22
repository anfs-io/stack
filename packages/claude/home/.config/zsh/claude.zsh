# claude.zsh

# Shortcuts
alias cc="clear; claude"
alias cc-continue="clear; claude --continue"
alias cc-yolo="clear; claude --dangerously-skip-permissions"
alias cc-resume="clear; claude --resume"
alias cc-version="claude --version"

# Start claude with specific permissions
alias cc-rw='clear; claude --allowedTools "Read" "Edit" "Grep" "Find" "ListDir" "WebSearch" "Bash"'

cconf() {
  local dir=$HOME/.claude/context file="." ext="md"
  load_conf "$@"
}
