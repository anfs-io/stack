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

# apply a template to an existing rails app/plugin
rat() {
  local templates_dir="${XDG_CONFIG_HOME}/rails/templates"

  if [[ "$1" == "ls" ]]; then
    shift
    echo "$templates_dir"
    ls "$@" "$templates_dir"
    return $?
  fi

  local template="main"
  if [[ -n "$1" && "$1" != -* ]]; then
    template="$1"
    shift
  fi

  ( cd "$(rails_app_dir)" && rails app:template LOCATION="${templates_dir}/${template}.rb" "$@" )
}

alias rce="rails credentials:edit"
alias rcs="rails credentials:show"

alias rdbc="rails app:db:clobber"

alias rg="rails generate"
alias rgm="rails generate model"
alias rgs="rails generate scaffold"

# alias rn="rails new --css=tailwind -T"
alias rn="rails new"

# Remove the omz rp alias to rails plugin new
[[ -n "${aliases[rp]}" ]] && unalias rp

# Generate a rails engine
alias rpn="rails plugin new -T --rc ~/.config/rails/railsrc"
# Generate a rails engine with bundled Rails application for testing
# alias rpnf="rails plugin new --full --dummy-path=spec/dummy --rc ~/.config/rails/pluginrc"
alias rpnf="rpn --full --dummy-path=spec/dummy"

# Generate mountable isolated engine - implies full
# alias rpnm="rails plugin new --mountable --rc ~/.config/rails/pluginrc"
# adds isolate_namespace to engine.rb
alias rpnm="rpnf --mountable"

# Remove the omz rs alias to rails server
[[ -n "${aliases[rs]}" ]] && unalias rs

ras() {
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

  # Boot the server
  (
    cd "$(rails_app_dir)" || exit 1

    if [[ -x "bin/dev" ]]; then
      PORT="$port" bin/dev
    else
      rails server -b "$base_ip" -p "$port"
    fi
  )
}


# ral - rails log - tail the rails log in app or spec/dummy
_ra_log() {
  if [[ "$1" == "ls" ]]; then
    shift
    ls "$@" "$(rails_app_dir)/log"
    return $?
  fi

  # Default environment
  local env="development"

  case "$1" in
    t*) env="test" ;;
    p*) env="production" ;;
  esac

  local log_file="log/${env}.log"
  (
    cd "$(rails_app_dir)" || exit 1
    mkdir -p log
    [[ ! -f "$log_file" ]] && touch "$log_file"
    tail -f "$log_file"
  )
}

# NOTE: rcd is currently a chorus fucntion to cd repo $1
# rcdd() {
#   # 1. Run your function to see if we are in/near a Rails app environment
#   local app_dir
#   app_dir=$(rails_app_dir) || return 0
# 
#   # 2. Identify the dummy path style being used
#   local dummy_path=""
#   if [[ -d spec/dummy || "$PWD" == */spec/dummy ]]; then
#     dummy_path="spec/dummy"
#   elif [[ -d test/dummy || "$PWD" == */test/dummy ]]; then
#     dummy_path="test/dummy"
#   else
#     return 0 # Not a Rails engine context
#   fi
# 
#   # 3 & 4. Toggle logic
#   if [[ "$app_dir" == "." ]]; then
#     # We are physically inside a Rails app directory.
#     # Check if this Rails app directory is actually the engine's dummy app.
#     if [[ "$PWD" == */"$dummy_path" ]]; then
#       # We are in the dummy app -> CD upward to the engine root
#       cd "${PWD%/$dummy_path}"
#     else
#       # It's just a normal standalone Rails app, do nothing
#       return 0
#     fi
#   else
#     # rails_app_dir returned "spec/dummy" or "test/dummy".
#     # We are at the engine root -> CD into that dummy directory
#     cd "$app_dir"
#   fi
# }

# temp dust
# rad() {
#   local parent_dir=~/spikes/chorus/scratch
#   local target_dir="$parent_dir/dust"
#   local force=false
# 
#   # Parse flags
#   local OPTIND opt
#   while getopts ":f" opt; do
#     case "$opt" in
#       f) force=true ;;
#       *) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
#     esac
#   done
#   shift $((OPTIND-1))
# 
#   # If -f is passed: wipe, recreate, and step in
#   if [ "$force" = true ]; then
#     cd "$parent_dir" || return 1
#     rm -rf dust
#     rails new dust
#     cd dust || return 1
# 
#     # Check for and execute custom setup script if it exists
#     if [[ -f "../dust.sh" ]]; then
#       echo "Executing custom setup script: ../dust.sh"
#       source "../dust.sh"
#     fi
#   else
#     # No flag: just try to cd into the dust directory
#     if [ -d "$target_dir" ]; then
#       cd "$target_dir"
#     else
#       echo "Directory does not exist yet. Run 'dust -f' to generate it." >&2
#       return 1
#     fi
#   fi
# }



# Main dispatcher function
ra() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: ra <subcommand> [args...]" >&2
    return 1
  fi

  local subcmd="$1"
  shift

  # 1. Check for exact match (_ra_dust)
  if typeset -f "_ra_${subcmd}" > /dev/null; then
    "_ra_${subcmd}" "$@"
    return $?
  fi

  # 2. Pattern match prefix against available _ra_* functions
  local matches=()
  for fn in ${(k)functions}; do
    if [[ "$fn" == _ra_${subcmd}* ]]; then
      matches+=("$fn")
    fi
  done

  # 3. Route or report errors
  if [[ ${#matches[@]} -eq 1 ]]; then
    "${matches[1]}" "$@"
  elif [[ ${#matches[@]} -gt 1 ]]; then
    echo "Ambiguous command '$subcmd'. Matches: ${matches#_ra_}" >&2
    return 1
  else
    echo "Unknown command '$subcmd'" >&2
    return 1
  fi
}

# Dust implementation
_ra_dust() {
  local base_name="dust"
  local force=false
  local OPTIND opt app_name xdg_config config_file target_dir

  # Parse options
  while getopts "n:f" opt; do
    case "${opt}" in
      n)
        base_name="${OPTARG}"
        ;;
      f)
        force=true
        ;;
      \?)
        echo "Usage: ra dust [-f] [-n name] [suffix]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  app_name="${base_name}$1"

  # Check XDG_CONFIG_HOME for target directory
  xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  config_file="${xdg_config}/rails/dust"

  if [[ -f "$config_file" ]]; then
    target_dir=$(head -n 1 "$config_file" | xargs)
    if [[ -n "$target_dir" && -d "$target_dir" ]]; then
      cd "$target_dir" || return 1
    fi
  fi

  # Handle existing directory/file overwrite safety check
  if [[ -e "$app_name" ]]; then
    if [[ "$force" == true ]]; then
      rm -rf "$app_name"
    else
      echo "Warning: '$app_name' already exists. Use -f to force removal." >&2
      return 1
    fi
  fi

  # Conditional execution: Run shell file if present, otherwise generate Rails app
  if [[ -f "${app_name}.sh" ]]; then
    source "./${app_name}.sh"
  else
    rails new "$app_name" || return 1
  fi

  # Move into directory if created/exists
  if [[ -d "$app_name" ]]; then
    cd "$app_name" || return 1
  fi
}
