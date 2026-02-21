# solana.zsh


# Add solana release path to the search path
if [[ ":$PATH:" != *":$HOME/.local/share/solana/install/active_release/bin:"* ]]; then
  export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
fi
