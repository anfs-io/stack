
gem_group :development, :test do
  gem('factory_bot_rails')
  gem('rspec-rails')
end

gem('amazing_print')
gem('pry-rails')

rails_command("g rspec:install")
# generate(:scaffold, "person name:string")
# route "root to: 'people#index'"
# rails_command("db:migrate")

after_bundle do
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end
