# main.rb

require "pry"

# Only templates with answer files present in init_path will be applied
# def strict? = true
 def strict? = false

# Search in ~/.config/rails/templates and ~/.local/share/rails/templates
def search_dirs = @search_dirs ||= [ENV.fetch('XDG_CONFIG_HOME', nil), ENV.fetch('XDG_DATA_HOME', nil)]

def template_dirs = @template_dirs ||= search_dirs.compact.map { |path| Pathname.new(path).join('rails/templates') }

def available_templates = @available_templates ||= {}

# Create a hash of name => path_to_template
template_dirs.flat_map { |dir| dir.glob('*.rb').select(&:file?) }.each_with_object(available_templates) do |path, hash|
  hash[path.basename(path.extname).to_s] = path
end

return if available_templates.empty?

# The dir where the `rails <plugin> new` command was invoked
def init_path = @init_path ||= Pathname.new(destination_root).parent

def config_file = @config_file ||= init_path.join("template.yml")

return if strict? && !config_file.exist?

require 'yaml'

def answers = @answers ||= config_file.exist? ? YAML.safe_load(config_file.read) : {}

return if strict? && answers.empty?

def selected_templates = @selected_templates ||= []

class Template
  attr_accessor :name, :template, :selected_features, :selected_gems

  def initialize(name:, template:, config:)
    @name = name
    @template = template
    config = Thor::CoreExt::HashWithIndifferentAccess.new(config)
    @selected_features = config.features || []
    @selected_gems = config.gems || []
  end
end

def yes_with_default?(statement, default_yes = false)
  suffix = default_yes ? "[Y/n]" : "[y/N]"
  default_val = default_yes ? "Y" : "N"

  response = ask("#{statement} #{suffix}", default: default_val)
  %w[y yes].include?(response.to_s.downcase)
end

# If strict? then apply only templates that are defined in the config file, otherwise all found templates
keys_to_iterate = strict? ? available_templates.keys.intersection(answers.keys) : available_templates.keys

keys_to_iterate.each_with_object(selected_templates) do |name, ary|
  # If not strict? then prompt the user for each template; The default is whether the key is found in the config file or not
  next unless strict? || yes_with_default?("Apply Template '#{name}'? (y/N)", answers.key?(name))

  ary.append Template.new(name: name, template: available_templates[name], config: answers[name])
end

return if selected_templates.empty?

#
# Method Helpers for the applied template(s)
#
def generator_type = @generator_type ||= self.class.name.demodulize.chomp("Generator").downcase

def plugin? = @plugin ||= generator_type.eql?("plugin")

def app? = @app ||= generator_type.eql?("app")

@custom_after_bundle_callbacks = []

def after_bundling(&block)
  @custom_after_bundle_callbacks << block
end

def after_messages = @after_messages ||= []

def say_after(msg, color = nil)
  after_messages.append({ msg: msg, color: color })
end

#
# Apply the Templates
#
def tpl = @tpl

selected_templates.each do |template|
  @tpl = template
  apply(template.template.to_s)
end

#
# Process after applying all selected templates
#

def git_add_and_commit
  git add: "."
  git commit: %Q{ -m 'Initial commit' }
end

def print_after_messages
  after_messages.each do | msg |
    if msg[:color]
      say msg[:msg], msg[:color]
    else
      say msg[:msg]
    end
  end
end

if app?
  after_bundle do
    git_add_and_commit
    print_after_messages
  end
else
  after_bundling do
    git_add_and_commit
    print_after_messages
  end
end

#
# If this is a plugin then invoke `bundle install` and execute all after_bundling blocks added by templates
# If this is an app then `bundle install` is invoked automatically by the system
#
if plugin?
  say_status "bundling", "Running bundle install...", :green

  # Run bundler within the destination root directory
  inside destination_root do
    if system("bundle install")
      say_status "success", "Bundle complete! Executing post-bundle callbacks...", :green

      # Loop through and execute every registered block in order (FIFO)
      @custom_after_bundle_callbacks.each do |callback|
        instance_eval(&callback)
      end
    else
      say_status "error", "Bundle install failed. Skipping callbacks.", :red
      exit(1)
    end
  end
end
