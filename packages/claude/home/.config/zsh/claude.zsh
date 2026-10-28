# claude.zsh

# --- Shortcuts ---
_invoke_claude() {
  claude "$@"
}

alias cc="clear; _invoke_claude $@"
alias cc-continue="cc --continue $@"
alias cc-resume="cc --resume $@"
alias cc-version="claude --version"

# alias cc-yolo="clear; _invoke_claude --dangerously-skip-permissions $@"
alias cc-yolo="cc --dangerously-skip-permissions $@"
alias cc-yolo-continue="cc-yolo --continue $@"
alias cc-yolo-resume="cc-yolo --resume $@"


# cconf() {
#   local dir=$HOME/.claude/context file="." ext="md"
#   load_conf "$@"
# }
