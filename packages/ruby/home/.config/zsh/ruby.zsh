# ruby.zsh

# Add ~/.local/lib/ruby to Ruby's search path (Idempotent)
[[ ":$RUBYLIB:" != *":$LIB_DIR/ruby:"* ]] && \
  export RUBYLIB="$LIB_DIR/ruby${RUBYLIB:+:$RUBYLIB}"
# ruby/tools.zsh

export RUBY_LOCAL_GEMS_HOME="$XDG_DATA_HOME/gems"

# Single bin dir from bundle install
ensure_path "$RUBY_LOCAL_GEMS_HOME/bin"

# Build RUBYLIB from all gem lib/ dirs. Rebuilt on every shell start (dropping
# any inherited entries) so gems linked since the parent shell started show up
() {
  local -a keep=(${(s.:.)RUBYLIB})
  keep=(${keep:#$RUBY_LOCAL_GEMS_HOME/*})
  local -a libs=("$RUBY_LOCAL_GEMS_HOME"/*/lib(N/) $keep)
  export RUBYLIB=${(j.:.)libs}
}

zcomp gem-local

# Wrapper to handle `local-gems cd` since subshells can't change parent directory
gem-local() {
  if [[ "${1:-}" == "cd" ]]; then
    shift
    local dir
    dir=$(command gem-local path "$@") || return $?
    builtin cd "$dir"
  else
    command gem-local "$@"
  fi
}

# bu - bundle
alias bua="bundle add"

bucd() {
  if [[ -z "$1" ]]; then
    echo "Usage: bucd <gem-name> [subpath]"
    return 1
  fi

  local gem_path
  gem_path=$(bundle show "$1" 2>/dev/null)

  if [[ -z "$gem_path" || ! -d "$gem_path" ]]; then
    echo "Error: Could not find gem '$1' in current bundle."
    return 1
  fi

  local target_path="$gem_path"
  if [[ -n "$2" ]]; then
    target_path="$gem_path/$2"
  fi

  if [[ -d "$target_path" ]]; then
    cd "$target_path" || return 1
  else
    echo "Error: Path '$target_path' does not exist."
    return 1
  fi
}

alias buf="bundle fund"

bug() {
  bundle gem --git --mit --test=rspec --no-ci --linter=rubocop --coc --no-changelog "$1"
  rm -rf "$1/.git"
}

alias bui="bundle install"

# ru - rubocop
# Auto fix the current dir (default) or the path passed in
rua() {
  rubocop -A "${1:-.}"
}

alias rmlsp='find . -type d -name .ruby-lsp -prune -exec rm -rf {} +'
