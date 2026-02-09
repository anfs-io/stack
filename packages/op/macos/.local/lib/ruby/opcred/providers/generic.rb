# frozen_string_literal: true

module OpCreds
  module Providers
    # Generic provider for any service type
    class Generic < Base
      attr_reader :provider_name

      def initialize(name = "generic")
        super()
        @provider_name = name
      end

      def build_credential(options)
        site = options[:site]
        service = options[:service]
        vault = options[:vault] || config.vault_for(:default)

        Credential.new(
          category: "login",
          title: build_title(provider_name, site, service),
          vault: vault,
          tags: build_tags(provider_name, site, service),
          url: options[:url],
          username: options[:username],
          password: options[:password]
        )
      end

      def rotate(existing_item)
        client = OpClient.instance

        # Generate new password
        new_password = SecureRandom.base64(24)

        # Update the item
        client.edit_item(
          existing_item["id"],
          vault: existing_item.dig("vault", "id"),
          password: new_password
        )
      end
    end
  end
end
