# Claude

alias cl="clear; claude"
alias clc="clear; claude --continue"
alias cldsp="clear; claude --dangerously-skip-permissions"
alias clr="clear; claude --resume"

clu() {
  local base_dir="$HOME/.local/share/npm"
  if [[ "$1" == "-g" ]]; then
    base_dir="/usr/local"
  fi
  rm -rf "${base_dir}/lib/node_modules/@anthropic-ai/claude-code"
  npm i -g @anthropic-ai/claude-code
}

alias clv="claude --version"
