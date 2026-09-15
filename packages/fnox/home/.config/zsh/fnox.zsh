# fnox.zsh

if command -v fnox >/dev/null 2>&1; then
  eval "$(fnox activate zsh)"
  zcomp fnox
fi

