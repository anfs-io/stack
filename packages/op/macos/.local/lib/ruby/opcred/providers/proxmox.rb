# frozen_string_literal: true

module OpCreds
  module Providers
    # Proxmox VE credential management
    class Proxmox < Base
      def build_credential(options)
        site = options[:site]
        vault = options[:vault] || config.vault_for(:default)
        username = options[:username] || "root@pam"

        # Proxmox uses realm-based auth, default is PAM
        username = "#{username}@pam" unless username.include?("@")

        fields = {
          "Node" => options[:node] || "",
          "Realm" => username.split("@").last
        }

        Credential.new(
          category: "login",
          title: build_title("Proxmox", site),
          vault: vault,
          tags: build_tags("proxmox", site, nil, extra: ["hypervisor"]),
          fields: fields.reject { |_, v| v.to_s.empty? },
          url: options[:url],
          username: username,
          password: options[:password]
        )
      end

      def rotate(existing_item)
        client = OpClient.instance

        # Generate new password
        new_password = SecureRandom.base64(24)

        # Update 1Password
        result = client.edit_item(
          existing_item["id"],
          vault: existing_item.dig("vault", "id"),
          password: new_password
        )

        if result.success?
          # Warn about manual Proxmox update
          warn "Updated 1Password. Remember to update Proxmox:"
          username = existing_item.dig("fields")&.find { |f| f["label"] == "username" }&.dig("value")
          warn "  pveum passwd #{username || "root@pam"}"
        end

        result
      end
    end
  end
end
