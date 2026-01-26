# rails

dependencies() {
  echo "ruby"
}

post_install() {
  source <(mise activate bash)
  install_gem \
    foreman pg rails \
    factory_bot_rails \
    pry-rails \
    rspec-rails \
    rubocop-rails rubocop-rspec_rails \
    ruby-lsp-rails \
    tailwindcss-rails
}
