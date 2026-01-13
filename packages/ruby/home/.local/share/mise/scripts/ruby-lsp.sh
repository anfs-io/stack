#!/bin/bash
# Reinstall ruby-lsp for Mason after Ruby installation

if ! command -v nvim &> /dev/null; then
  echo "nvim not found, skipping ruby-lsp reinstall"
  exit 0
fi

echo "Reinstalling ruby-lsp for nvim Mason..."
nvim --headless -c "lua require('mason-registry').get_package('ruby-lsp'):uninstall()" -c "qa" 2>/dev/null || true
sleep 2
nvim --headless -c "lua require('mason-registry').get_package('ruby-lsp'):install()" -c "qa" 2>/dev/null || true
echo "ruby-lsp reinstalled successfully"
