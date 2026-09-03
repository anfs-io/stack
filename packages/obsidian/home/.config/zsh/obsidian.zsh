# obsidian

if [[ "$(os)" == "macos" ]]; then
  alias ob="/Applications/Obsidian.app/Contents/MacOS/Obsidian"
  alias cdi="cd $HOME/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents"
fi

oconf() {
  local dir=$XDG_CONFIG_HOME/nvim/lua/plugins/obsidian file="../obsidian.lua" ext="lua"
  load_conf "$@"
}
