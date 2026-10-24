# obsidian

if [[ "$(os)" == "macos" ]]; then
  alias ob="/Applications/Obsidian.app/Contents/MacOS/Obsidian"
  # alias cdi="cd $HOME/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents"
  # Set the base environment variable
  export OBSIDIAN_DATA_HOME="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"

  # Define the cdi function
  cdi() {
      local target="$OBSIDIAN_DATA_HOME"

      # If a subdirectory argument is passed, append it
      if [[ -n "$1" ]]; then
          target="$target/$1"
      fi

      cd "$target"
  }
fi

oconf() {
  local dir=$XDG_CONFIG_HOME/nvim/lua/plugins/obsidian file="../obsidian.lua" ext="lua"
  load_conf "$@"
}
