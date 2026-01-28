# frozen_string_literal: true

require "open3"
require "json"
require "singleton"

module OpCreds
  # Wrapper around the 1Password CLI
  # Provides a single entry point for all op commands with consistent error handling
  class OpClient
    include Singleton

    Result = Struct.new(:success?, :data, :error, keyword_init: true)

    attr_accessor :debug

    def initialize
      @debug = ENV["OPCREDS_DEBUG"] == "1"
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Item operations
    # ─────────────────────────────────────────────────────────────────────────

    def create_item(category:, title:, vault:, tags: nil, fields: {}, **extra)
      args = ["item", "create"]
      args += ["--category", category]
      args += ["--title", title]
      args += ["--vault", vault]
      args += ["--tags", tags] if tags
      args += ["--format", "json"]

      # Add fields
      fields.each do |label, value|
        args << field_assignment(label, value)
      end

      # Add extra fields (for things like url)
      extra.each do |key, value|
        args << "#{key}=#{value}" if value
      end

      run(*args)
    end

    def get_item(item, vault: nil)
      args = ["item", "get", item, "--format", "json"]
      args += ["--vault", vault] if vault
      run(*args)
    end

    def edit_item(item, vault: nil, **updates)
      args = ["item", "edit", item]
      args += ["--vault", vault] if vault

      updates.each do |label, value|
        args << field_assignment(label, value)
      end

      run(*args)
    end

    def delete_item(item, vault: nil, archive: true)
      args = ["item", "delete", item]
      args += ["--vault", vault] if vault
      args << "--archive" if archive
      run(*args)
    end

    def list_items(vault: nil, tags: nil, categories: nil)
      args = ["item", "list", "--format", "json"]
      args += ["--vault", vault] if vault
      args += ["--tags", tags] if tags
      args += ["--categories", categories] if categories
      run(*args)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Vault operations
    # ─────────────────────────────────────────────────────────────────────────

    def list_vaults
      run("vault", "list", "--format", "json")
    end

    def get_vault(vault)
      run("vault", "get", vault, "--format", "json")
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Read operations (for templates and automation)
    # ─────────────────────────────────────────────────────────────────────────

    def read(reference)
      # reference format: op://vault/item/field
      args = ["read", reference]
      result = run(*args)

      # read returns plain text, not JSON
      if result.success?
        Result.new(success?: true, data: result.data.strip)
      else
        result
      end
    end

    def inject(template)
      # Inject secrets into a template string
      # Uses op inject from stdin
      stdout, stderr, status = Open3.capture3("op", "inject", stdin_data: template)

      if status.success?
        Result.new(success?: true, data: stdout)
      else
        Result.new(success?: false, error: stderr.strip)
      end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Session management
    # ─────────────────────────────────────────────────────────────────────────

    def signed_in?
      result = run("account", "list", "--format", "json")
      result.success? && !result.data.empty?
    end

    def whoami
      run("whoami", "--format", "json")
    end

    private

    def run(*args)
      cmd = ["op"] + args
      log_command(cmd) if @debug

      stdout, stderr, status = Open3.capture3(*cmd)

      if status.success?
        data = parse_output(stdout, args)
        Result.new(success?: true, data: data)
      else
        Result.new(success?: false, error: parse_error(stderr))
      end
    rescue Errno::ENOENT
      Result.new(success?: false, error: "1Password CLI (op) not found. Install with: mise install op")
    end

    def parse_output(stdout, args)
      return stdout if stdout.empty?

      # Check if we requested JSON output
      if args.include?("--format") && args[args.index("--format") + 1] == "json"
        JSON.parse(stdout)
      else
        stdout.strip
      end
    rescue JSON::ParserError
      stdout.strip
    end

    def parse_error(stderr)
      # Clean up op error messages
      stderr.strip.sub(/^\[ERROR\]\s*\d{4}\/\d{2}\/\d{2}\s*\d{2}:\d{2}:\d{2}\s*/, "")
    end

    def field_assignment(label, value)
      # Determine field type based on label or value hints
      type = infer_field_type(label, value)
      "#{label}[#{type}]=#{value}"
    end

    def infer_field_type(label, _value)
      label_lower = label.to_s.downcase

      if label_lower.include?("password") || label_lower.include?("secret") || label_lower.include?("key")
        "concealed"
      elsif label_lower.include?("url")
        "url"
      elsif label_lower.include?("otp") || label_lower.include?("totp")
        "otp"
      else
        "text"
      end
    end

    def log_command(cmd)
      # Redact sensitive values
      redacted = cmd.map do |arg|
        if arg.include?("=") && (arg.include?("password") || arg.include?("secret"))
          arg.sub(/=.*/, "=<REDACTED>")
        else
          arg
        end
      end
      warn "[DEBUG] #{redacted.join(" ")}"
    end
  end
end
