# frozen_string_literal: true
# telemetry.rb

# Guard check if this template was invoked by the main template or on CLI with -m
unless defined?(tpl)
  require Pathname.new(ENV.fetch("XDG_CONFIG_HOME", "#{Dir.home}/.config")).join("rails/lib")
  validate_context
end

binding.pry
# The remaining gems only make sense if they are installed in an app
# return unless app?

gems_array = %w(opentelemetry-sdk sentry-rails)
 
gems_array.select! { |name| yes?("Add gem '#{name}'? (y/N)") }.each { |gem| gem(gem) }

if gems_array.include?("sentry-rails")
  # TODO Add sentry config to be written to initializer
  # TODO Add this test route to config/routes.rb
  # get "down" => proc { raise "Test GlitchTip error!" }
end
