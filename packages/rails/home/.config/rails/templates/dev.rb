# new.rb
#
# Standard gem + tooling setup

gem_group :development, :test do
  gem('factory_bot_rails')
  gem('rspec-rails')
end

gem_group :development do
  gem('ruby-lsp-rspec', require: false)
  gem('ruby-lsp-rails', require: false)
end

# TODO: Template class shall have the method to install the gems as per the selected_gems
# but also for the template to prompt when this template adds suggestions
# available_gems = ["amazing_print", "pry-rails", "tailwindcss-rails"]

tpl.selected_gems.each { |gemx| gem(gemx) }

# gem('amazing_print')
# gem('pry-rails')
# gem('tailwindcss-rails')

rails_command("generate rspec:install")

rails_command("tailwindcss:install") if app?
system("bin/rails tailwindcss:install") if plugin? && options.full

return unless app?

# TODO; Need a discriminator for app vs plugin in template.yml
gems_array = %w(opentelemetry-sdk sentry-rails)
# gems_array = %w(flipper lockbox okcomputer opentelemetry-sdk sentry-rails)
 
gems_array.select { |name| yes?("Add gem '#{name}'? (y/N)") }.each { |gem| gem(gem) }

if gems_array.include?("sentry-rails")
  # TODO Add sentry config to be written to initializer
  # TODO Add this test route to config/routes.rb
  # get "down" => proc { raise "Test GlitchTip error!" }
end
