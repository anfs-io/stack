# frozen_string_literal: true

# This template is designed to be invoked once and only at intital create of an app or plugin
# It is automatically invoked by `rails new` from ~/.config/rails/railsrc OR
#  `rails plugin new` by passing `--rc=..`

config_path = ENV.fetch("XDG_CONFIG_HOME", "#{Dir.home}/.config")
main_rb_path = Pathname.new(config_path).join("rails/main.rb")

unless main_rb_path.exist?
  say "WARN: #{main_rb_path} not found!", :red
  return
end

apply(main_rb_path.to_s)

after_bundling(__FILE__) do
  git_add_and_commit
  print_after_messages
end

# If this is a plugin then invoke `bundle install` and execute all after_bundling blocks added by templates
# If this is an app then `bundle install` is invoked automatically by the system
if plugin?
  # So rails.vim works
  create_file("config/environment.rb") if options.full

  say_status "bundling", "Running bundle install...", :green

  # Run bundler within the destination root directory
  inside(destination_root) do
    if system("bundle install")
      say_status "success", "Bundle complete! Executing post-bundle callbacks...", :green

      # Loop through and execute every registered block in order (FIFO)
      custom_after_bundle_callbacks.each do |callback|
        instance_eval(&callback)
      end
    else
      say_status "error", "Bundle install failed. Skipping callbacks.", :red
      exit(1)
    end
  end
end
