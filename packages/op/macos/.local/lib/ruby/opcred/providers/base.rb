# frozen_string_literal: true

module OpCreds
  module Providers
    # Factory method to get provider by name
    def self.for(name)
      case name.to_s.downcase
      when "aws"
        AWS.new
      when "proxmox"
        Proxmox.new
      else
        Generic.new(name)
      end
    end

    # Base class for all providers
    class Base
      def build_credential(options)
        raise NotImplementedError, "Subclass must implement #build_credential"
      end

      def rotate(existing_item)
        raise NotImplementedError, "Subclass must implement #rotate"
      end

      protected

      def config
        @config ||= OpCreds::Config.load
      end

      def build_title(provider, site, service = nil)
        title = "#{capitalize(provider)} - #{capitalize(site)}"
        title += " - #{service}" if service
        title
      end

      def build_tags(provider, site, service = nil, extra: [])
        tags = [provider.downcase, site.downcase, "infrastructure"]
        tags << service.downcase if service
        tags += Array(extra)
        tags.uniq
      end

      def capitalize(str)
        str.to_s.split(/[_-]/).map(&:capitalize).join(" ")
      end

      def default_region(site)
        site_cfg = config.site_config(site)
        site_cfg["aws_region"] || "us-east-1"
      end
    end
  end
end
