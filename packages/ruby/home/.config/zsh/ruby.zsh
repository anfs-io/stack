# ruby.zsh

# Idempotent
[[ ":$RUBYLIB:" != *":$LIB_DIR/ruby:"* ]] && \
  export RUBYLIB="$LIB_DIR/ruby${RUBYLIB:+:$RUBYLIB}"

# Auto fix the current dir (default) or the path passed in
ra() {
  rubocop -A "${1:-.}"
}
