# frozen_string_literal: true

require "dry/cli"
require "json"
require "open3"
require "erb"
require "pathname"
require "securerandom"

# Load support files
require_relative "op_client"
require_relative "credential"
require_relative "config"

# Load providers
require_relative "providers/base"
require_relative "providers/generic"
require_relative "providers/aws"
require_relative "providers/proxmox"

module OpCred
  module CLI
    extend Dry::CLI::Registry

    # ─────────────────────────────────────────────────────────────────────────
    # Commands
    # ─────────────────────────────────────────────────────────────────────────

    class Version < Dry::CLI::Command
      desc "Print version"

      def call(*)
        puts "opcred 0.1.0"
      end
    end

    class Create < Dry::CLI::Command
      desc "Create a new credential in 1Password"

      option :provider, aliases: ["-p"], required: true,
        desc: "Provider type (aws, proxmox, kubernetes, traefik, generic)"
      option :site, aliases: ["-s"], required: true,
        desc: "Site identifier (singapore, us, etc.)"
      option :service, aliases: ["-S"],
        desc: "Service name (optional, for sub-services)"
      option :vault, aliases: ["-v"], default: "HomeLab",
        desc: "1Password vault name"
      option :username, aliases: ["-u"],
        desc: "Username for the credential"
      option :url,
        desc: "Service URL"
      option :password,
        desc: "Provide password instead of generating"
      option :dry_run, type: :boolean, default: false,
        desc: "Show what would be created without creating"

      example [
        "-p proxmox -s singapore -u root --url https://pve.sg.lab:8006",
        "-p aws -s singapore -S terraform -v AWS-Operations",
        "-p generic -s us -u admin --service traefik"
      ]

      def call(**options)
        provider = Providers.for(options[:provider])
        credential = provider.build_credential(options)

        if options[:dry_run]
          puts "Would create:"
          puts credential.to_op_args.join(" \\\n  ")
        else
          result = credential.save
          if result.success?
            puts "Created: #{credential.title} in #{credential.vault}"
          else
            warn "Error: #{result.error}"
            exit 1
          end
        end
      end
    end

    class Get < Dry::CLI::Command
      desc "Retrieve a credential from 1Password"

      argument :item, required: true, desc: "Item name or ID"

      option :vault, aliases: ["-v"],
        desc: "Vault to search in"
      option :field, aliases: ["-f"],
        desc: "Specific field to retrieve"
      option :format, aliases: ["-F"], default: "text", values: %w[text json env],
        desc: "Output format"

      example [
        "\"Proxmox - Singapore Lab\"",
        "\"AWS Singapore\" -f \"Access Key ID\"",
        "\"Proxmox - US Lab\" --format env"
      ]

      def call(item:, **options)
        client = OpClient.instance
        result = client.get_item(item, vault: options[:vault])

        unless result.success?
          warn "Error: #{result.error}"
          exit 1
        end

        output = format_output(result.data, options)
        puts output
      end

      private

      def format_output(data, options)
        if options[:field]
          field = data["fields"]&.find { |f| f["label"] == options[:field] }
          field ? field["value"] : "Field not found"
        else
          case options[:format]
          when "json"
            JSON.pretty_generate(data)
          when "env"
            fields_to_env(data["fields"] || [])
          else
            format_text(data)
          end
        end
      end

      def fields_to_env(fields)
        fields.filter_map do |f|
          next unless f["value"]
          key = f["label"].upcase.gsub(/[^A-Z0-9]/, "_")
          "#{key}=#{f["value"]}"
        end.join("\n")
      end

      def format_text(data)
        lines = ["Title: #{data["title"]}"]
        lines << "Vault: #{data.dig("vault", "name")}"
        if data["fields"]
          lines << "\nFields:"
          data["fields"].each do |f|
            next if f["purpose"] == "NOTES"
            value = f["type"] == "CONCEALED" ? "********" : f["value"]
            lines << "  #{f["label"]}: #{value}"
          end
        end
        lines.join("\n")
      end
    end

    class List < Dry::CLI::Command
      desc "List credentials matching criteria"

      option :vault, aliases: ["-v"],
        desc: "Vault to search in"
      option :provider, aliases: ["-p"],
        desc: "Filter by provider tag"
      option :site, aliases: ["-s"],
        desc: "Filter by site tag"
      option :format, aliases: ["-F"], default: "text", values: %w[text json],
        desc: "Output format"

      example [
        "-v HomeLab",
        "-p aws -s singapore",
        "--format json"
      ]

      def call(**options)
        client = OpClient.instance
        result = client.list_items(
          vault: options[:vault],
          tags: build_tags(options)
        )

        unless result.success?
          warn "Error: #{result.error}"
          exit 1
        end

        output = format_list(result.data, options[:format])
        puts output
      end

      private

      def build_tags(options)
        tags = []
        tags << options[:provider] if options[:provider]
        tags << options[:site] if options[:site]
        tags.empty? ? nil : tags.join(",")
      end

      def format_list(items, format)
        case format
        when "json"
          JSON.pretty_generate(items)
        else
          items.map { |i| "#{i["title"]} (#{i.dig("vault", "name")})" }.join("\n")
        end
      end
    end

    class Rotate < Dry::CLI::Command
      desc "Rotate credentials for a service"

      argument :item, required: true, desc: "Item name or ID to rotate"

      option :vault, aliases: ["-v"],
        desc: "Vault containing the item"
      option :dry_run, type: :boolean, default: false,
        desc: "Show what would be changed without rotating"

      def call(item:, **options)
        client = OpClient.instance

        # Get existing item
        result = client.get_item(item, vault: options[:vault])
        unless result.success?
          warn "Error: #{result.error}"
          exit 1
        end

        existing = result.data
        provider_tag = detect_provider(existing)
        provider = Providers.for(provider_tag)

        if options[:dry_run]
          puts "Would rotate credentials for: #{existing["title"]}"
          puts "Provider: #{provider_tag}"
        else
          rotate_result = provider.rotate(existing)
          if rotate_result.success?
            puts "Rotated: #{existing["title"]}"
          else
            warn "Error: #{rotate_result.error}"
            exit 1
          end
        end
      end

      private

      def detect_provider(item)
        tags = item["tags"] || []
        %w[aws proxmox kubernetes traefik].find { |p| tags.include?(p) } || "generic"
      end
    end

    class Config < Dry::CLI::Command
      desc "Show or set configuration"

      argument :key, desc: "Configuration key"
      argument :value, desc: "Value to set (omit to show current value)"

      option :list, aliases: ["-l"], type: :boolean,
        desc: "List all configuration"

      example [
        "--list",
        "default_vault",
        "default_vault HomeLab"
      ]

      def call(key: nil, value: nil, **options)
        config = OpCreds::Config.load

        if options[:list]
          puts config.to_yaml
        elsif value
          config.set(key, value)
          config.save
          puts "Set #{key} = #{value}"
        elsif key
          puts config.get(key) || "(not set)"
        else
          puts "Usage: opcred config [--list | KEY [VALUE]]"
        end
      end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Register commands
    # ─────────────────────────────────────────────────────────────────────────

    register "version", Version, aliases: ["v", "-v", "--version"]
    register "create", Create, aliases: ["c", "new"]
    register "get", Get, aliases: ["g", "show"]
    register "list", List, aliases: ["ls"]
    register "rotate", Rotate, aliases: ["r"]
    register "config", Config

    # ─────────────────────────────────────────────────────────────────────────
    # Entry point
    # ─────────────────────────────────────────────────────────────────────────

    def self.call
      Dry::CLI.new(self).call
    end
  end
end
