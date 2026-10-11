# frozen_string_literal: true

require 'pry'
require 'yaml'
require 'bundler'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/deep_dup'

###
class Config
  attr_accessor :config, :templates

  def initialize(config: {}, templates: {})
    @config = config
    @templates = templates
  end

  def strict? = config[:strict] || false
end

def config_x = @config_x ||= Config.new(**config_values)

def config_values
  @config_values||= template_config_files.each_with_object({}) do |file, hash|
    hash.deep_merge!(YAML.safe_load(ERB.new(file.read).result, permitted_classes: [Symbol]))
  end.deep_symbolize_keys
end

def template_config_files
  @config_files ||= (
    template_config_paths.map{ |path| path.join('template.yml') }.
    append(init_path.join("#{app_name}.yml")).
    select(&:exist?)
  )
end

def template_config_paths
  @template_config_paths ||= [config_path, data_path, init_path, project_path]
end

# Use the name of the template file to determine the key and create a Template instance to hold values
def set_template(file, generator)
  name = path_to_name(file)
  @tpl = templates[name] ||= Template.new(name: name, generator: generator,
    config: generator.instance_variable_get("@config_x").templates[name]&.deep_dup || {})
  @tpl
end

def templates = @templates ||= {}

class Template
  attr_accessor :name, :config, :gems

  def initialize(name:, generator:, config:)
    @name = name
    @generator = generator
    @config = config
    @gem_groups = {}
    @current_groups = [:default]
    @gems = {}
    @status = nil
  end

  def plugin? = @generator.instance_variable_get("@generator_type").eql?("plugin")

  def feature(name)
    config[:features].include?(name) || @generator.yes?("Add feature '#{name}'?")
  end

  def gem_group(*groups, &block)
    previous_groups = @current_groups
    @current_groups = groups
    instance_eval(&block) if block_given?
  ensure
    @current_groups = previous_groups
  end

  def gem(name, **options)
    @gem_groups[@current_groups] ||= {}
    @gem_groups[@current_groups][name] = options
  end

  def gemspec(name, *requirements)
    gemspec_file = "#{@generator.instance_variable_get("@app_name")}.gemspec"

    # Format arguments: "phlex-rails", "~> 2.4", ">= 2.0"
    formatted_args = ([name.inspect] + requirements.map(&:inspect)).join(", ")
    binding.pry

    @generator.inject_into_file gemspec_file, before: /^end/ do
      "  spec.add_dependency #{formatted_args}\n"
    end
  end

  def apply
    return unless @status.nil?

    @gem_groups.each do |groups, gem_set|
      # Set @gems so that `select_gems` will reference the correct set
      @gems = gem_set

      # Prompt the user for gem inclusion if necessary and collect the filtered results
      sel = gems.slice(*select_gems).each_with_object({}) do |(name, options), hash|
        next if gem_installed?(name)
        hash[name] = options.slice(:path, :platforms, :require)
      end

      # Add dependencies to the gemspec if this is a plugin
      gems.slice(*sel.keys).each do |name, options|
        gemspec(name, *options.slice(:requirements).values.flatten) if options[:gemspec] 
      end if plugin?

      if groups.include?(:default)
        # For default group just invoke the generator's gem method
        sel.each do |name, values|
          @generator.gem(name, values)
        end
      else
        # For all other groups invoke the generator's gem_group method unless there are no gems
        @generator.gem_group(*groups) do
          sel.each do |name,values|
            gem(name, values)
          end
        end unless sel.empty?
      end
      selected_gems.merge!(sel)
    end
    Bundler.reset!
    @status = :applied
  end

  def selected_gems = @selected_gems ||= {}

  def select_gems
    # target_keys are names of the gems to defined in the template
    target_keys = gems.keys

    # `slice` ignores any additional gems defined in the config files
    gems.deep_merge!(config[:gems].stringify_keys.slice(*target_keys)) if config[:gems]

    # required gems are auto included; optional and undefined are prompted to the user
    # any other value for `install`, e.g. `skip` will be ignored
    gems(install: [:optional, nil]).keys.each_with_object(gems(install: :required).keys) do |name, ary|
      ary.append(name) if @generator.yes?("Add gem '#{name}'?")
    end
  end

  def gems(**filter)
    return @gems if filter.empty?

    @gems.select do |_name, attributes|
      filter.all? do |key, expected_val|
        if expected_val.is_a?(Array)
          expected_val.include?(attributes[key])
        else
          attributes[key] == expected_val
        end
      end
    end
  end

  def gem_installed?(name) = !Bundler.definition.dependencies.find { |dep| dep.name == name }.nil?
end


def tpl = @tpl

def path_to_name(path)
  path = Pathname.new(path)
  path.basename(path.extname).to_s.to_sym
end

def dummy_app? = @dummy_app ||= app? && !project_path.join("Gemfile").exist?

def app? = @app ||= generator_type.eql?("app")

def plugin? = @plugin ||= generator_type.eql?("plugin")

def generator_type = @generator_type ||= self.class.name.demodulize.chomp("Generator").downcase

# Return a hash of name => path_to_template
def templates_map
  @templates_map ||= template_files.each_with_object({}) do |path, hash|
    hash[path_to_name(path)] = path
  end
end

def template_files
  @template_files ||= template_paths.flat_map { |path| path.glob('[^_]*.rb').select(&:file?) }
end

def template_paths
  @template_paths ||= [config_path, data_path, init_path].map { |path| path.join('templates') }
end

def config_path
  @config_path ||= Pathname.new(ENV.fetch("XDG_CONFIG_HOME", "#{Dir.home}/.config")).join("rails")
end

def data_path
  @data_path ||= Pathname.new(ENV.fetch('XDG_DATA_HOME', "#{Dir.home}/.local/share")).join("rails")
end

def init_path = @init_path ||= project_path.parent

def project_path = @project_path ||= Pathname.new(destination_root)


###

def yes_with_default?(statement, default_yes = false)
  suffix = default_yes ? "[Y/n]" : "[y/N]"
  default_val = default_yes ? "Y" : "N"

  response = ask("#{statement} #{suffix}", default: default_val)
  %w[y yes].include?(response.to_s.downcase)
end

def custom_after_bundle_callbacks = @custom_after_bundle_callbacks ||= []

def after_bundle_plugin(&block)
  custom_after_bundle_callbacks << block
end

def after_bundling(file, &block)
  return unless block_given?

  if app?
    after_bundle do
      set_template(file, self)
      instance_eval(&block)
    end
  elsif plugin? # && options.full
    after_bundle_plugin do
      set_template(file, self)
      instance_eval(&block)
    end
  end
end

def after_messages = @after_messages ||= []

def say_after(msg, color = nil)
  after_messages.append({ msg: msg, color: color })
end

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

# `rails plugin new` does accept a value for template -m  which implies templates are supported, however
#   when applying a template using `rails app:template LOCATION=..` it only works in an app or dummy
#   so any generators intending to apply changes to a plugin must do it only at plugin create time
def validate_context
  if dummy_app?
    say "WARN: Cannot run template(s) against a plugin after initial create", :red
    exit(1)
  end
  config_x
end
