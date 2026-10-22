# rails.sh — portable (bash and zsh); generic Rails helpers for any app or engine.
# The omz alias cleanup is in .config/zsh/rails.zsh; cnfs-specific tooling is cnfs/rails's partitia.sh

# Echo the nearest Rails app dir relative to $PWD:
#   .           -> current dir is itself a Rails app (config/application.rb)
#   spec/dummy  -> we're at a plugin root with an RSpec dummy
#   test/dummy  -> we're at a plugin root with a Minitest dummy
# Returns non-zero (echoes nothing) if none found.
rails_app_dir() {
  if [[ -f config/application.rb ]]; then
    printf '%s\n' .
  elif [[ -f spec/dummy/config/application.rb ]]; then
    printf '%s\n' spec/dummy
  elif [[ -f test/dummy/config/application.rb ]]; then
    printf '%s\n' test/dummy
  else
    return 1
  fi
}

alias rce="rails credentials:edit"
alias rcs="rails credentials:show"

alias rg="rails generate"
alias rgm="rails generate model"
alias rgs="rails generate scaffold"

alias rn="rails new"

# ras [port] - rails server on 0.0.0.0; without a port, the first free one from 3000
ras() {
  local base_ip="0.0.0.0"
  local port

  if [[ -n "${1:-}" ]]; then
    port="$1"
  else
    port=3000
    while lsof -i :$port -sTCP:LISTEN -t >/dev/null 2>&1; do
      echo "Port $port is busy, checking next..."
      ((port++))
    done
    echo "Found open port: $port"
  fi

  (
    cd "$(rails_app_dir)" || exit 1

    if [[ -x "bin/dev" ]]; then
      PORT="$port" bin/dev
    else
      rails server -b "$base_ip" -p "$port"
    fi
  )
}

# ral [t|p|ls] - tail the development (or test/production) log in the app or spec/dummy
ral() {
  if [[ "${1:-}" == "ls" ]]; then
    shift
    ls "$@" "$(rails_app_dir)/log"
    return $?
  fi

  local env="development"

  case "${1:-}" in
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
