# pdt/gems.zsh

_gems_root="$XDG_DATA_HOME/gems"

# Add bin dirs from all repo dirs found
for _repo_dir in "$_gems_root"/*(N/); do
  [[ -d "$_repo_dir/bin" ]] && ensure_path "$_repo_dir/bin"
done

# Build RUBYLIB from all gem lib/ dirs across all repos
[[ ":$RUBYLIB:" != *":$_gems_root/"* ]] && {
  _gem_paths=()
  for gemlib in "$_gems_root"/*/*/lib(N/); do
    _gem_paths+=("$gemlib")
  done
  _joined=$(IFS=:; echo "${_gem_paths[*]}")
  export RUBYLIB="${_joined}${RUBYLIB:+:$RUBYLIB}"
  unset _gem_paths _joined
}
unset _gems_root _repo_dir
