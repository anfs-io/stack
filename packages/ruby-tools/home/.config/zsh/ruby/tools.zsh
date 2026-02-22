# ruby/tools.zsh

# Auto fix the current dir (default) or the path passed in
ra() {
  rubocop -A "${1:-.}"
}

gem-new() {
  bundle gem --git --mit --test=rspec --no-ci --linter=rubocop --coc --no-changelog "$1"
  rm -rf "$1/.git"
}
