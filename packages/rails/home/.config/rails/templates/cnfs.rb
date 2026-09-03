# frozen_string_literal: true

# Guard check if this template was invoked by the main template or on CLI with -m
unless defined?(tpl)
  require Pathname.new(ENV.fetch("XDG_CONFIG_HOME", "#{Dir.home}/.config")).join("rails/lib")
  validate_context
end

set_template(__FILE__, self)

# Relative path to the Chorus project's gems
def rel_path_to_gem(name) = rel_path_to_gems.join(name).to_s

def rel_path_to_gems
  @rel_path_to_gems ||= chorus_path.join("gems").relative_path_from(destination_root)
end

# TODO: Replace this hard coded path with a value from the template's config file
# Need to apply ERB to the YAML
def chorus_path = @chorus_path ||= Pathname.new(Dir.home).join("spikes/chorus")


tpl.gem("cnfs_support", path: rel_path_to_gem("support"), gemspec: true, install: :required)
tpl.gem("cnfs_dev", path: rel_path_to_gem("dev"), gemspec: true, install: :required)

### Feature Selection
# NOTE: if `tpl.feature` took a block then rel_path_to_gems is not accessible
if tpl.feature("UI")
  tpl.gem("cnfs_ui", path: rel_path_to_gem("ui"), install: :required)
end

if tpl.feature("Multi-Tenant")
  tpl.gem("cnfs_tenanted", path: rel_path_to_gem("tenanted"), gemspec: true, install: :required)
end

if tpl.feature("IAM")
  tpl.gem("iam", path: rel_path_to_gem("iam"), gemspec: true, install: :required)
  tpl.gem("cnfs_cognito", path: rel_path_to_gem("cognito"), gemspec: true, install: :required)
end

if tpl.feature("Chorus")
  tpl.gem("cnfs_okf", path: rel_path_to_gem("okf"), gemspec: true, install: :required)
  tpl.gem("chorus", path: rel_path_to_gem("chorus"), gemspec: true, install: :required)
end

if tpl.feature("Telemetry")
  tpl.gem("cnfs_telemetry", path: rel_path_to_gem("telemetry"), gemspec: true, install: :required)
end

if app? && tpl.feature("Chat")
  tpl.gem("chatter", path: rel_path_to_gem("chatter"), gemspec: true, install: :required)
end

tpl.apply

def run_install_generators(gems_selected)
  rails_command("generate chatter:install") if gems_selected.include? "chatter"
  rails_command("generate cnfs_cognito:install") if gems_selected.include? "cnfs_cognito"
  rails_command("generate cnfs_support:install") if gems_selected.include? "cnfs_support"
  rails_command("generate cnfs_telemetry:install") if gems_selected.include? "cnfs_telemetry"
  rails_command("generate cnfs_tenanted:install") if gems_selected.include? "cnfs_tenanted"
  rails_command("generate cnfs_ui:install") if gems_selected.include? "cnfs_ui"
end

if plugin? && options.full
  after_bundling do
    set_template(__FILE__, self)
    run_install_generators(tpl.selected_gems)
  end
elsif app?
  after_bundle do
    set_template(__FILE__, self)
    run_install_generators(tpl.selected_gems)
  end
end
