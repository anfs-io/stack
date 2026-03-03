# obsidian

alias ob="/Applications/Obsidian.app/Contents/MacOS/Obsidian"

oconf() {
  local dir=$XDG_CONFIG_HOME/nvim/lua/plugins/obsidian file="../obsidian.lua" ext="lua"
  load_conf "$@"
}
