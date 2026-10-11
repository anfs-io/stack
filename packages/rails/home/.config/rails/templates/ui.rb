# frozen_string_literal: true

# Guard check if this template was invoked by the main template or on CLI with -m
unless defined?(config_x)
  require Pathname.new(ENV.fetch("XDG_CONFIG_HOME", "#{Dir.home}/.config")).join("rails/lib")
  validate_context
end

set_template(__FILE__, self)

tpl.gem("tailwindcss-rails", install: :required)
# tpl.gem("phlex-rails", path: "#{Dir.home}/spikes/eval/phlex-rails")
tpl.gem("phlex-rails")
tpl.gem("ruby_ui", path: "#{Dir.home}/spikes/eval/ruby_ui")

tpl.gem_group :development do
  gem("lookbook") 
end

tpl.apply

if tpl.selected_gems.include?("tailwindcss-rails")
  rails_command("tailwindcss:install") if app?
  system("bin/rails tailwindcss:install") if plugin? && options.full
end


# TODO; Need a discriminator for app vs plugin in template.yml
# gems_array = %w(phlex-rails ruby_ui lookbook)


if tpl.selected_gems.include?("phlex-rails")
  #rails_command("generate phlex:install") # if app?
end

if tpl.selected_gems.include?("ruby_ui")
#   rails_command("generate ruby_ui:install") # if app?
end

if tpl.selected_gems.include?("lookbook")
  route <<~RUBY
  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
RUBY
  # binding.pry
  if tpl.gem_installed?("rspec-rails")
    if app?
      environment "config.lookbook.preview_paths = [ \"spec/components/previews\" ]", env: "development"
    else
      target_file = "#{options.dummy_path}/config/environments/development.rb"
      inject_into_file(target_file, after: "Rails.application.configure do\n") do
<<~RUBY.indent(2)
  # Configure component preview paths for Lookbook
  # NOTE: while the value *must* be an Array, it must contain *only* 1 entry
  config.lookbook.preview_paths = [ Rails.root.parent.parent.join("spec/components/previews").to_s ]

RUBY
      end
    end
  end
end

# apply(Pathname.new(__FILE__).parent.join("_ui_plugin.rb").to_s) if plugin? && options.full
