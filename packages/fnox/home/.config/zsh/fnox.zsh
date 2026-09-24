# fnox.zsh

if command -v fnox >/dev/null 2>&1; then
  eval "$(fnox activate zsh)"
  zcomp fnox
fi

fconf() {
  local dir=$XDG_CONFIG_HOME/fnox file="config.toml" ext="toml"
  load_conf "$@"
}

