
return unless yes?("install Hotwire, Turbo and Tailwind support in the dummy app?")

say "Parsing plugin structure for Engine-level Hotwire & Tailwind configuration...", :green

#
# Hotwire (Turbo + Stimulus) + Tailwind support for a --mountable Rails engine.
#
# Usage on a new engine:
#   rails plugin new my_engine --mountable -m hotwire_plugin_template.rb
#
# Usage on an existing engine (run from the engine root):
#   bin/rails app:template LOCATION=hotwire_plugin_template.rb
#
# What it does:
#   1. Adds turbo-rails / stimulus-rails / importmap-rails / tailwindcss-rails
#      to the gemspec.
#   2. Requires them in the engine file so their railties load for both the
#      dummy app and any host app that mounts the engine.
#   3. Wires importmap + JS entrypoints + Stimulus into the dummy app.
#   4. Adds a Tailwind v4 entry stylesheet to the dummy app.
#   5. Updates the dummy layout: importmap tags + compiled tailwind stylesheet.
#   6. Drops in a "hello" Stimulus controller as a smoke test.
#
# Stack assumptions (matches a vanilla Rails 8.1 mountable engine):
#   - propshaft asset pipeline
#   - importmap (no Node build step)
#   - tailwindcss-rails v4 via the standalone tailwindcss-ruby CLI (no Node)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Engine module name, e.g. "Okf", and gem name, e.g. "okf".
engine_module = (defined?(camelized) && camelized) || app_const_base
gem_name      = (defined?(original_app_name) && original_app_name) || engine_module.underscore

# Locate the dummy app (RSpec uses spec/dummy, default generator uses test/dummy).
dummy_root = options.dummy_path

say "Using dummy app at #{dummy_root}", :green

# ---------------------------------------------------------------------------
# 1. Gemspec dependencies
# ---------------------------------------------------------------------------

# NOTE: Under which circumstances should a plugin declare these deps?
# Since the host app must declare these also, it's redundant to put them in the gemspec
# though for the dummy app they should be in the Gemfile
# tpl.gem("turbo-rails", gemspec: true)
# tpl.gem("stimulus-rails", gemspec: true)
# tpl.gem("importmap-rails", gemspec: true)
# tpl.gem("tailwindcss-rails", gemspec: true)
gemspec_path = "#{gem_name}.gemspec"

if File.exist?(File.join(destination_root, gemspec_path))
  insert_into_file gemspec_path, before: /^end\s*\z/ do
    <<-RUBY
  spec.add_dependency "turbo-rails"
  spec.add_dependency "stimulus-rails"
  spec.add_dependency "importmap-rails"
  spec.add_dependency "tailwindcss-rails"
    RUBY
  end
else
  say "Could not find #{gemspec_path}; add the turbo/stimulus/importmap/tailwind deps manually.", :red
end

# ---------------------------------------------------------------------------
# 2. Require the railties from the engine + use Tailwind for generators
# ---------------------------------------------------------------------------

engine_file = "lib/#{gem_name}/engine.rb"

if File.exist?(File.join(destination_root, engine_file))
  prepend_to_file engine_file do
    <<~RUBY
      require "turbo-rails"
      require "stimulus-rails"
      require "importmap-rails"
      require "tailwindcss-rails"

    RUBY
  end

  # Make `rails g scaffold` (and view generators) emit Tailwind-styled ERB.
  # tailwindcss-rails ships Tailwindcss::Generators::* templates that win when
  # the template engine is set to :tailwindcss. Without this, scaffolds in the
  # engine come out as plain unstyled Rails views.
  inject_into_file engine_file, after: /isolate_namespace .*\n/ do
    <<-RUBY

    config.generators do |g|
      g.template_engine :tailwindcss
    end
    RUBY
  end
else
  say "Could not find #{engine_file}; add the requires + generators config manually.", :red
end

# ---------------------------------------------------------------------------
# 3. Dummy app: importmap + JS entrypoints
# ---------------------------------------------------------------------------

create_file "#{dummy_root}/config/importmap.rb", <<~RUBY, force: true
  # Pin npm packages by running ./bin/importmap

  pin "application"
  pin "@hotwired/turbo-rails", to: "turbo.min.js"
  pin "@hotwired/stimulus", to: "stimulus.min.js"
  pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
  pin_all_from "app/javascript/controllers", under: "controllers"
RUBY

create_file "#{dummy_root}/app/javascript/application.js", <<~JS, force: true
  // Entrypoint for the dummy app's importmap (config/importmap.rb)
  import "@hotwired/turbo-rails"
  import "controllers"
JS

create_file "#{dummy_root}/app/javascript/controllers/application.js", <<~JS, force: true
  import { Application } from "@hotwired/stimulus"

  const application = Application.start()

  // Configure Stimulus development experience
  application.debug = false
  window.Stimulus = application

  export { application }
JS

create_file "#{dummy_root}/app/javascript/controllers/index.js", <<~JS, force: true
  import { application } from "controllers/application"
  import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
  eagerLoadControllersFrom("controllers", application)
JS

# Smoke-test controller so you can verify Stimulus connects.
create_file "#{dummy_root}/app/javascript/controllers/hello_controller.js", <<~JS, force: true
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    connect() {
      this.element.textContent = "Hello from Stimulus"
    }
  }
JS

# ---------------------------------------------------------------------------
# 3b. Ensure engine dirs scanned by Tailwind exist
# ---------------------------------------------------------------------------
#
# CRITICAL for `tailwindcss:watch`. The Bun/oxide-based Tailwind v4 CLI sets up
# a filesystem watcher on every @source base directory. `tailwindcss:build`
# tolerates a @source dir that does not exist (it just matches nothing), but
# `tailwindcss:watch` ERRORS with "No such file or directory" when asked to
# watch a directory that is absent. A fresh engine may have no app/helpers
# dir yet (scaffolds create app/views), so we create the @source base dirs
# with .keep files to guarantee every @source base below resolves to a real
# directory.
#
# NOTE: only list dirs you actually scan. If you later adopt view components
# (e.g. ViewComponent/Phlex in app/components), add both a .keep here and a
# matching @source line in the entry CSS below.

["app/views", "app/helpers"].each do |dir|
  create_file File.join(dir, ".keep"), "", force: true
  # Also for the dummy app, whose own views/helpers are @source bases too.
  create_file File.join(dummy_root, dir, ".keep"), "", force: true
end

# ---------------------------------------------------------------------------
# 4. Dummy app: Tailwind v4 entry stylesheet
# ---------------------------------------------------------------------------
#
# tailwindcss-rails v4 compiles app/assets/tailwind/application.css into
# app/assets/builds/tailwind.css, which propshaft then serves. The @source
# directives tell Tailwind which files to scan for class names.

create_file "#{dummy_root}/app/assets/tailwind/application.css", <<~CSS, force: true
  @import "tailwindcss";

  /* Scan the dummy app's own views/helpers... */
  @source "../../../app/views/**/*";
  @source "../../../app/helpers/**/*.rb";

  /* ...and the ENGINE's app dir, since `rails g scaffold` generates
     Tailwind-classed views into the engine. The entry file lives at
     <dummy>/app/assets/tailwind/application.css. Climbing to the engine root:
       ../ assets  ../ app  ../ <dummy>  ../ spec|test  ../ engine-root
     i.e. five levels up. */
  @source "../../../../../app/views/**/*";
  @source "../../../../../app/helpers/**/*.rb";
CSS

# ---------------------------------------------------------------------------
# 4b. Engine layout: load Tailwind
# ---------------------------------------------------------------------------
#
# An isolated engine's ApplicationController renders inside the engine's own
# layout: app/views/layouts/<engine>/application.html.erb. The scaffold
# generator creates this layout if it is absent, but that generated layout only
# links the engine's propshaft "<engine>/application" stylesheet -- NOT the
# compiled Tailwind build -- so scaffolded pages render unstyled even when the
# views carry Tailwind classes.
#
# We pre-create the engine layout here with the compiled "tailwind" stylesheet
# linked. Because it already exists, the later scaffold run will NOT overwrite
# it, so engine pages pick up Tailwind. The "tailwind" asset is resolved by
# propshaft from the dummy's app/assets/builds/tailwind.css at request time.

create_file "app/views/layouts/#{gem_name}/application.html.erb", <<~ERB, force: true
  <!DOCTYPE html>
  <html>
    <head>
      <title><%= content_for(:title) || "#{engine_module}" %></title>
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <%= csrf_meta_tags %>
      <%= csp_meta_tag %>

      <%= yield :head %>

      <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
      <%= javascript_importmap_tags %>
    </head>
    <body>
      <%= yield %>
    </body>
  </html>
ERB

# ---------------------------------------------------------------------------
# 5. Dummy layout: importmap tags + compiled tailwind stylesheet
# ---------------------------------------------------------------------------

layout_path = "#{dummy_root}/app/views/layouts/application.html.erb"

if File.exist?(File.join(destination_root, layout_path))
  layout = File.read(File.join(destination_root, layout_path))

  # 5a. importmap tags — anchor before </head> so it is independent of the
  #     stylesheet rewrite below.
  unless layout.include?("javascript_importmap_tags")
    insert_into_file layout_path,
      "    <%= javascript_importmap_tags %>\n  ",
      before: %r{</head>}
  end

  # 5b. Tailwind stylesheet. With propshaft, linking :app would also serve the
  #     unprocessed tailwind source, so link the compiled "tailwind" build
  #     explicitly (in addition to :app for any other engine/app CSS).
  unless layout.include?(%(stylesheet_link_tag "tailwind"))
    if layout.match?(/<%=\s*stylesheet_link_tag\s+:app.*%>/)
      insert_into_file layout_path,
        %(    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>\n),
        before: /<%=\s*stylesheet_link_tag\s+:app.*%>/
    else
      insert_into_file layout_path,
        %(    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>\n  ),
        before: %r{</head>}
    end
  end
else
  say "Could not find #{layout_path}; add the importmap + tailwind link tags manually.", :red
end

# ---------------------------------------------------------------------------
# 5b. Dummy dev runner: foreman + Procfile.dev (server + tailwind watcher)
# ---------------------------------------------------------------------------
def deprecated
#
# The plugin generator's dummy bin/dev only starts the server. Replace it with
# the canonical Rails 8 bin/dev (auto-installs foreman, sets PORT/debug env)
# and add a Procfile.dev that runs the server alongside `tailwindcss:watch`,
# so editing views auto-rebuilds Tailwind -- no manual `tailwindcss:build`.

create_file "#{dummy_root}/Procfile.dev", <<~PROCFILE, force: true
  web: bin/rails server -p 3000
  css: bin/rails tailwindcss:watch
PROCFILE

create_file "#{dummy_root}/bin/dev", <<~'SH', force: true
  #!/usr/bin/env sh

  if ! gem list foreman -i --silent; then
    echo "Installing foreman..."
    gem install foreman
  fi

  # Default to port 3000 if not specified
  export PORT="${PORT:-3000}"

  # Let the debug gem allow remote connections,
  # but avoid loading until `debugger` is called
  export RUBY_DEBUG_OPEN="true"
  export RUBY_DEBUG_LAZY="true"

  exec foreman start -f Procfile.dev "$@"
SH

# create_file does not set the executable bit; chmod via the shell.
run "chmod +x #{dummy_root}/bin/dev"
end

# ---------------------------------------------------------------------------
# 6. Initial Tailwind build + done
# ---------------------------------------------------------------------------
#
# This first build only emits Tailwind's base/reset layer, because no styled
# views exist yet at plugin-creation time. You MUST rebuild after generating
# scaffolds/views or Tailwind utility classes (bg-blue-600, rounded-md, etc.)
# will be missing and pages will look unstyled.

say "", :green
say "Hotwire + Tailwind support added.", :green
say "", :green
say "Develop with the server + Tailwind watcher (auto-rebuilds on save):", :yellow
say %(  (cd #{dummy_root} && bin/dev)), :yellow
say "", :green
say "One-off Tailwind build (e.g. before running specs):", :yellow
say %(  (cd #{dummy_root} && bin/rails tailwindcss:build)), :yellow
