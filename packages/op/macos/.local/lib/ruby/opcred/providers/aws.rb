# frozen_string_literal: true

module OpCreds
  module Providers
    # AWS-specific credential management
    # Supports IAM users, access keys, and role-based access
    class AWS < Base
      def build_credential(options)
        site = options[:site]
        service = options[:service] || "default"
        vault = options[:vault] || config.vault_for(:aws_operations)

        site_cfg = config.site_config(site)
        region = site_cfg["aws_region"] || default_region(site)

        fields = {
          "Access Key ID" => options[:access_key_id] || "",
          "Secret Access Key" => options[:secret_access_key] || "",
          "Region" => region,
          "Account ID" => options[:account_id] || "",
          "IAM User" => "svc-#{service}",
          "Role ARN" => options[:role_arn] || ""
        }

        Credential.new(
          category: "login",
          title: build_title("AWS", site, service),
          vault: vault,
          tags: build_tags("aws", site, service),
          fields: fields.compact
        )
      end

      def rotate(existing_item)
        # AWS rotation is more complex - we need to:
        # 1. Create a new access key via AWS API
        # 2. Update 1Password with the new key
        # 3. Delete the old key
        #
        # For now, we just warn that manual steps are needed
        # Full implementation would require aws-sdk-iam

        warn "AWS credential rotation requires AWS API access."
        warn "To rotate manually:"
        warn "  1. aws iam create-access-key --user-name <user>"
        warn "  2. Update 1Password with new credentials"
        warn "  3. aws iam delete-access-key --user-name <user> --access-key-id <old-key>"

        OpClient::Result.new(
          success?: false,
          error: "Manual rotation required for AWS credentials"
        )
      end

      # Generate IAM policy for the CredentialManager role
      def credential_manager_policy(account_id:)
        require "erb"
        require "json"

        template_path = File.join(__dir__, "..", "templates", "iam_credential_manager_policy.json.erb")

        unless File.exist?(template_path)
          return default_credential_manager_policy(account_id)
        end

        template = ERB.new(File.read(template_path))
        JSON.parse(template.result(binding))
      end

      private

      def default_credential_manager_policy(account_id)
        {
          "Version" => "2012-10-17",
          "Statement" => [
            {
              "Sid" => "ManageIAMServiceUsers",
              "Effect" => "Allow",
              "Action" => [
                "iam:CreateUser",
                "iam:DeleteUser",
                "iam:CreateAccessKey",
                "iam:DeleteAccessKey",
                "iam:ListAccessKeys",
                "iam:UpdateAccessKey",
                "iam:PutUserPolicy",
                "iam:DeleteUserPolicy",
                "iam:AttachUserPolicy",
                "iam:DetachUserPolicy",
                "iam:TagUser",
                "iam:UntagUser"
              ],
              "Resource" => "arn:aws:iam::#{account_id}:user/svc-*"
            },
            {
              "Sid" => "ManageSecretsManager",
              "Effect" => "Allow",
              "Action" => [
                "secretsmanager:CreateSecret",
                "secretsmanager:UpdateSecret",
                "secretsmanager:DeleteSecret",
                "secretsmanager:GetSecretValue",
                "secretsmanager:TagResource"
              ],
              "Resource" => "arn:aws:secretsmanager:*:#{account_id}:secret:lab/*"
            }
          ]
        }
      end
    end
  end
end
