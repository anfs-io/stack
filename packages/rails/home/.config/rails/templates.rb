# templates.rb
#
# Interactive application-template dispatcher.
# Iterates over sibling template files and asks whether to apply each one.
#
# Selection UI, in order of preference (graceful fallback):
#   1. gum  (charmbracelet) — multi-select with fuzzy search
#   2. fzf  (junegunn)      — multi-select with fuzzy search
#   3. Thor's yes? prompt   — one yes/no per template, zero deps
#
# Conventions:
#   - This file and any file beginning with "_" are skipped (partials/dispatcher).
#   - Each candidate is applied via `apply`, so it runs in this generator context.

# require "shellwords"
# require "pry"
require "pathname"

# Search in ~/.config/rails/templates and ~/.local/share/rails/templates
search_dirs = [ENV.fetch('XDG_CONFIG_HOME', nil), ENV.fetch('XDG_DATA_HOME', nil)]

template_dirs = search_dirs.compact.map { |path| Pathname.new(path).join('rails/templates') }

candidates = template_dirs.flat_map { |dir| dir.glob('*.rb').select(&:file?) }

if candidates.empty?
  say "No optional templates found in #{template_dirs.join(', ')}", :yellow
  return
end

# Human-friendly label for each path: "basic.rb"
labels = candidates.to_h { |path| [path.basename.to_s, path] }

selected = labels.keys.select { |name| yes?("Apply template '#{name}'? (y/N)") }

#   def tool?(name)
#     system("command -v #{name} > /dev/null 2>&1")
#   end

#   selected =
#     if tool?("gum")
#       out = `printf %s #{labels.keys.join("\n").shellescape} | \
#              gum choose --no-limit --header #{"Select templates to apply".shellescape}`
#       out.split("\n").map(&:strip).reject(&:empty?)
#     elsif tool?("fzf")
#       out = `printf %s #{labels.keys.join("\n").shellescape} | \
#              fzf --multi --prompt #{"templates> ".shellescape} \
#                  --header #{"TAB to select, ENTER to confirm".shellescape}`
#       out.split("\n").map(&:strip).reject(&:empty?)
#     else
#       labels.keys.select { |name| yes?("Apply template '#{name}'? (y/N)") }
#     end

  if selected.empty?
    say "No templates selected.", :yellow
  else
    selected.each do |name|
      path = labels[name]
      next unless path # guard against stray TUI output

      say "Applying #{name}...", :green
      apply path.to_s
    end
  end
