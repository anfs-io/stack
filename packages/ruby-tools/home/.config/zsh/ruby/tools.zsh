# ruby/tools.zsh

alias b_i="bundle install"

# Auto fix the current dir (default) or the path passed in
ra() {
  rubocop -A "${1:-.}"
}

b_n() {
  bundle gem --git --mit --test=rspec --no-ci --linter=rubocop --coc --no-changelog "$1"
  rm -rf "$1/.git"
}
