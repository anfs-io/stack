# frozen_string_literal: true

# Source the lib.rb functions
require Pathname.new(ENV.fetch("XDG_CONFIG_HOME", "#{Dir.home}/.config")).join("rails/lib")
validate_context

def selected_templates = @selected_templates ||= get_selected_templates

# rubocop:disable Naming/AccessorMethodName
def get_selected_templates
  # If strict? then retrun all templates that are defined in the config file
  return templates_map.keys.intersection(config_x.templates.keys) if config_x.strict?

  # If not strict? then prompt the user for each template
  # The default refelcts the presence of the key in config_values
  templates_map.keys.each_with_object([]) do |name, ary|
    ary.append(name) if yes_with_default?("Apply Template '#{name}'?", config_x.templates.key?(name))
  end
end
# rubocop:enable Naming/AccessorMethodName

# Determine if processing should continue
say("No template files found", :yellow) && return if templates_map.empty?

if config_x.strict? && config_x.templates.empty?
  say("No templates defined in config when in strict mode", :yellow)
  return
end

# Select/process templates
if selected_templates.empty?
  say("No templates available/selected", :yellow)
else
  selected_templates.each { |name| apply(templates_map[name].to_s) }
  templates.each_value(&:apply)
end
