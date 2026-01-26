# ruby.zsh

# Add ~/.local/lib/ruby to Ruby's search path (Idempotent)
[[ ":$RUBYLIB:" != *":$LIB_DIR/ruby:"* ]] && \
  export RUBYLIB="$LIB_DIR/ruby${RUBYLIB:+:$RUBYLIB}"
