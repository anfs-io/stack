# frozen_string_literal: true

require "yaml"
require "pathname"
require "fileutils"

module OpCreds
  # Configuration management for opcreds
  class Config
    CONFIG_DIR = Pathname.new(Dir.home).join(".config/opcreds")
    CONFIG_FILE = CONFIG_DIR.join("config.yml")

    DEFAULTS = {
      "default_vault" => "HomeLab",
      "aws_operations_vault" => "AWS-Operations",
      "aws_bootstrap_vault" => "AWS-Bootstrap",
      "sites" => {
        "singapore" => {
          "alias" => "sg",
          "aws_region" => "ap-southeast-1"
        },
        "us" => {
          "alias" => "us",
          "aws_region" => "us-east-1"
        }
      }
    }.freeze

    def self.load
      new
    end

    def initialize
      @data = DEFAULTS.dup

      if CONFIG_FILE.exist?
        loaded = YAML.safe_load(CONFIG_FILE.read, permitted_classes: [Symbol]) || {}
        @data = deep_merge(@data, loaded)
      end
    end

    def get(key)
      keys = key.to_s.split(".")
      keys.reduce(@data) { |h, k| h.is_a?(Hash) ? h[k] : nil }
    end

    def set(key, value)
      keys = key.to_s.split(".")
      last_key = keys.pop
      target = keys.reduce(@data) { |h, k| h[k] ||= {} }
      target[last_key] = value
    end

    def save
      CONFIG_DIR.mkpath unless CONFIG_DIR.exist?
      CONFIG_FILE.write(@data.to_yaml)
    end

    def to_yaml
      @data.to_yaml
    end

    def site_config(site)
      # Allow lookup by full name or alias
      sites = @data["sites"] || {}

      # Direct match
      return sites[site] if sites[site]

      # Alias match
      sites.each do |name, config|
        return config.merge("name" => name) if config["alias"] == site
      end

      # Default
      { "name" => site, "aws_region" => "us-east-1" }
    end

    def vault_for(type)
      case type.to_s
      when "aws_operations", "aws"
        get("aws_operations_vault")
      when "aws_bootstrap"
        get("aws_bootstrap_vault")
      else
        get("default_vault")
      end
    end

    private

    def deep_merge(base, override)
      base.merge(override) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end
  end
end
