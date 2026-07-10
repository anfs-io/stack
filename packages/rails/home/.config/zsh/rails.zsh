# rails.zsh

# Echo the nearest Rails app dir relative to $PWD:
#   .           -> current dir is itself a Rails app (config/application.rb)
#   spec/dummy  -> we're at a plugin root with an RSpec dummy
#   test/dummy  -> we're at a plugin root with a Minitest dummy
# Returns non-zero (echoes nothing) if none found.
rails_app_dir() {
  if [[ -f config/application.rb ]]; then
    print -r -- .
  elif [[ -f spec/dummy/config/application.rb ]]; then
    print -r -- spec/dummy
  elif [[ -f test/dummy/config/application.rb ]]; then
    print -r -- test/dummy
  else
    return 1
  fi
}

# rat() { ( cd "$(rails_app_dir)" && rails app:template LOCATION="${XDG_CONFIG_HOME:-$HOME/.config}/rails/templates.rb" "$@" ); }

rat() { ( cd "$(rails_app_dir)" && rails app:template LOCATION=$XDG_CONFIG_HOME/rails/templates.rb "$@" ); }
# alias rat="rails app:template LOCATION=$XDG_CONFIG_HOME/rails/templates.rb"

alias rce="rails credentials:edit"
alias rcs="rails credentials:show"

alias rdbc="rails app:db:clobber"
rdev() { ( cd "$(rails_app_dir)" && bin/dev "$@" ); }

rfs() { ( cd "$(rails_app_dir)" && foreman start -f Procfile.dev "$@" ); }

alias rg="rails generate"
alias rgm="rails generate model"
alias rgs="rails generate scaffold"

alias rn="rails new --css=tailwind -T"

# Generate a rails engine
alias rpn="rails plugin new -T --rc ~/.config/rails/railsrc"
# Generate a rails engine with bundled Rails application for testing
# alias rpnf="rails plugin new --full --dummy-path=spec/dummy --rc ~/.config/rails/pluginrc"
alias rpnf="rpn --full --dummy-path=spec/dummy"

# Generate mountable isolated engine - implies full
# alias rpnm="rails plugin new --mountable --rc ~/.config/rails/pluginrc"
# adds isolate_namespace to engine.rb
alias rpnm="rpnf --mountable"

# alias rsb="rails server -b 0.0.0.0"
rsb() {
  local base_ip="0.0.0.0"
  local port

  if [[ -n "$1" ]]; then
    # If a parameter was passed, use it directly as the port
    port="$1"
  else
    # Otherwise, find the next available port starting at 3000
    port=3000
    while lsof -i :$port -sTCP:LISTEN -t >/dev/null 2>&1; do
      echo "Port $port is busy, checking next..."
      ((port++))
    done
    echo "Found open port: $port"
  fi

  # Boot up the server
  rails server -b "$base_ip" -p "$port"
}

# -----------------
if alias rp >/dev/null 2>&1; then
  unalias rp
fi

# rtl - rails tail log - tail the rails log in app or spec/dummy
rtl() {
  # Default environment
  local env="development"

  # Parse optional flags
  while getopts "tp" opt; do
    case "$opt" in
      t) env="test" ;;
      p) env="production" ;;
      *) echo "Usage: rtl [-t] [-p]"; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  local log_file="log/${env}.log"
  # local log_dir="log"
  # local dummy_log="spec/dummy/log/${env}.log"
  local target_log=""

  # 1. Check if log/[env].log exists
  if [[ -d "log" ]]; then
    target_log="$log_file"
  # 2. Check if spec/dummy/log/[env].log exists
  elif [[ -d "spec/dummy/log" ]]; then
    target_log="spec/dummy/$log_file"
  fi
  touch "$target_log"
  echo "tailing $target_log"
  tail -f "$target_log"
}

cdd() {
  # 1. Run your function to see if we are in/near a Rails app environment
  local app_dir
  app_dir=$(rails_app_dir) || return 0

  # 2. Identify the dummy path style being used
  local dummy_path=""
  if [[ -d spec/dummy || "$PWD" == */spec/dummy ]]; then
    dummy_path="spec/dummy"
  elif [[ -d test/dummy || "$PWD" == */test/dummy ]]; then
    dummy_path="test/dummy"
  else
    return 0 # Not a Rails engine context
  fi

  # 3 & 4. Toggle logic
  if [[ "$app_dir" == "." ]]; then
    # We are physically inside a Rails app directory.
    # Check if this Rails app directory is actually the engine's dummy app.
    if [[ "$PWD" == */"$dummy_path" ]]; then
      # We are in the dummy app -> CD upward to the engine root
      cd "${PWD%/$dummy_path}"
    else
      # It's just a normal standalone Rails app, do nothing
      return 0
    fi
  else
    # rails_app_dir returned "spec/dummy" or "test/dummy".
    # We are at the engine root -> CD into that dummy directory
    cd "$app_dir"
  fi
}

# temp dust
dust() {
  local parent_dir=~/spikes/chorus/scratch
  local target_dir="$parent_dir/dust"
  local force=false

  # Parse flags
  local OPTIND opt
  while getopts ":f" opt; do
    case "$opt" in
      f) force=true ;;
      *) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
    esac
  done
  shift $((OPTIND-1))

  # If -f is passed: wipe, recreate, and step in
  if [ "$force" = true ]; then
    cd "$parent_dir" || return 1
    rm -rf dust
    rails new dust
    cd dust || return 1

    # Check for and execute custom setup script if it exists
    if [[ -f "../dust.sh" ]]; then
      echo "Executing custom setup script: ../dust.sh"
      source "../dust.sh"
    fi
  else
    # No flag: just try to cd into the dust directory
    if [ -d "$target_dir" ]; then
      cd "$target_dir"
    else
      echo "Directory does not exist yet. Run 'dust -f' to generate it." >&2
      return 1
    fi
  fi
}
