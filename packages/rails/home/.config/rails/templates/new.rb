# new.rb
#
# Standard gem + tooling setup

gem_group :development, :test do
  gem('factory_bot_rails')
  gem('rspec-rails')
end

gem_group :development do
  gem('ruby-lsp-rspec', require: false)
end

gem('amazing_print')
gem('pry-rails')

rails_command("generate rspec:install")

def create_first_commit
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end

if self.class.name.include?("PluginGenerator")
  say "Generating a plugin!"
  create_first_commit
else
  say "Generating an application!"
  after_bundle do
    # git :init
    create_first_commit
  end
end
