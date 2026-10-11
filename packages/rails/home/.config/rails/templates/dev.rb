# frozen_string_literal: true

# Guard check if this template was invoked by the main template or on CLI with -m
unless defined?(config_x)
  require Pathname.new(ENV.fetch("XDG_CONFIG_HOME", "#{Dir.home}/.config")).join("rails/lib")
  validate_context
end

set_template(__FILE__, self)

tpl.gem("flipper", install: :skip)
tpl.gem("lockbox", install: :skip)
tpl.gem("okcomputer", install: :skip)
tpl.gem("pry-rails", install: :optional)
tpl.gem("amazing_print", install: :optional)
# tpl.gem("dink", install: :required, gemspec: true, requirements: ["> 2", "< 3"])

tpl.gem_group :development do
  gem('ruby-lsp-rspec', require: false)
  gem('ruby-lsp-rails', require: false)
end

tpl.gem_group :development, :test do
  gem('factory_bot_rails')
  gem('rspec-rails')
end

after_bundling(__FILE__) do
  if tpl.selected_gems.include?('rspec-rails')
    # TODO: remove the generated test directory
    rails_command("generate rspec:install")
  end
end

after_bundle_plugin do
  engine_file = "lib/#{app_name}/engine.rb"

  inject_into_file engine_file, after: "isolate_namespace #{camelized}\n" do
    <<~RUBY.indent(4)

      config.generators do |g|
        g.test_framework :rspec
      end
    RUBY
  end
end

tpl.apply
