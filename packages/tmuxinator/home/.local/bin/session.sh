#!/usr/bin/zsh
# Initialize rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Extract session name and invoke tmuxinator on the argument
session=$(echo $1 | sed 's/rpi1-//')
tmuxinator $session
