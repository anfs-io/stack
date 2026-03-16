# pde/gems.zsh

_gems_root="$XDG_DATA_HOME/gems"

# Single bin dir from bundle install
[[ -d "$_gems_root/bin" ]] && ensure_path "$_gems_root/bin"

# Build RUBYLIB from all gem lib/ dirs
[[ ":$RUBYLIB:" != *":$_gems_root/"* ]] && {
  _gem_paths=()
  for gemlib in "$_gems_root"/*/lib(N/); do
    _gem_paths+=("$gemlib")
  done
  _joined=$(IFS=:; echo "${_gem_paths[*]}")
  export RUBYLIB="${_joined}${RUBYLIB:+:$RUBYLIB}"
  unset _gem_paths _joined
}
unset _gems_root
