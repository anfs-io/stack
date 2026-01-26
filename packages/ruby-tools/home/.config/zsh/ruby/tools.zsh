# ruby/tools.zsh

# Auto fix the current dir (default) or the path passed in
ra() {
  rubocop -A "${1:-.}"
}
