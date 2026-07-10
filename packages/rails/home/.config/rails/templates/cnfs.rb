# cnfs.rb

# return unless yes?("Add CNFS/Chorus available_features? (y/N)")

available_features = {
  UI: %w(ui),
  "Multi-Tenant": %w(tenanted),
  IAM: %w(iam cognito),
  Chorus: %w(okf chorus),
  Telemetry: %w(telemetry),
}

available_features.merge!({
  Chat: %w(chatter)
}) if app?

# Grab any features auto selected from template.yml
selected_features = tpl.selected_features.map(&:to_sym)

# prompt for features not already selected unless strict?
available_features.keys.difference(selected_features).each_with_object(selected_features).select do |name, ary|
  ary.append(name.to_sym) if yes?("Add '#{name}'? (y/N)")
end unless strict?

# Convert selected features into selected_gems
# selected_features.each_with_object(tpl.selected_gems) do |feature, ary|
selected_features.each do |feature|
  unless gem_list = available_features[feature]
    say "error: key not found #{feature}", :red
    next
  end

  tpl.selected_gems |= gem_list
end

tpl.selected_gems.prepend('support', 'dev').uniq!

# Prompt apps and plugins
# TODO: promote to a class or a structured hash; gem_map can also have installer: true, and if there is a path decleared then it is written
# otherwise it just adds to Gemfile
gem_map = {
  chatter: :chatter,
  chorus: :chorus,
  cognito: :cnfs_cognito,
  dev: :cnfs_dev,
  iam: :iam,
  okf: :cnfs_okf,
  support: :cnfs_support,
  telemetry: :cnfs_telemetry,
  tenanted: :cnfs_tenanted,
  ui: :cnfs_ui
}

return unless tpl.selected_gems.any?

# generator_namespace = "cnfs_support:install"
# ab = Rails::Generators.find_by_namespace(generator_namespace)
# binding.pry

# Now to the business of installing the requested gems

# Relative path to the Chorus project's gems
def rel_path_to_gems = @rel_path_to_gems ||= gems_path.relative_path_from(destination_root)

def gems_path = @gems_path ||= chorus_path.join("gems")

def chorus_path = @chorus_path ||= Pathname.new(Dir.home).join("spikes/chorus")

tpl.selected_gems.each do |lib|
  gem(gem_map[lib.to_sym].to_s, path: rel_path_to_gems.join(lib).to_s)
end

# run each selected gem's installer if it has one
# maybe just an array of which gems have an install generator and loop over it
def run_install_generators(gems_selected)
  rails_command("generate chatter:install") if gems_selected.include? "chatter"
  rails_command("generate cnfs_cognito:install") if gems_selected.include? "cognito"
  rails_command("generate cnfs_support:install") if gems_selected.include? "support"
  rails_command("generate cnfs_telemetry:install") if gems_selected.include? "telemetry"
  rails_command("generate cnfs_tenanted:install") if gems_selected.include? "tenanted"
  rails_command("generate cnfs_ui:install") if gems_selected.include? "ui"
end

after_bundling do
  run_install_generators(tpl.selected_gems)
end if plugin? && options.full

after_bundle do
  run_install_generators(tpl.selected_gems)
end if app?


# generate(:scaffold, "person name:string")
# rails_command("db:migrate")
# route "root to: 'people#index'"
