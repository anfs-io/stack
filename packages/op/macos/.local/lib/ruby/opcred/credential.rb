# frozen_string_literal: true

require "securerandom"

module OpCreds
  # Represents a credential to be stored in 1Password
  class Credential
    attr_accessor :category, :title, :vault, :tags, :fields, :url, :username, :password

    def initialize(
      category: "login",
      title:,
      vault: "HomeLab",
      tags: [],
      fields: {},
      url: nil,
      username: nil,
      password: nil
    )
      @category = category
      @title = title
      @vault = vault
      @tags = Array(tags)
      @fields = fields
      @url = url
      @username = username
      @password = password
    end

    def save
      client = OpClient.instance
      client.create_item(
        category: category,
        title: title,
        vault: vault,
        tags: tags.join(","),
        fields: build_fields,
        url: url
      )
    end

    def to_op_args
      args = ["op", "item", "create"]
      args += ["--category", category]
      args += ["--title", title]
      args += ["--vault", vault]
      args += ["--tags", tags.join(",")]

      build_fields.each do |label, value|
        type = infer_type(label)
        args << "#{label}[#{type}]=#{value}"
      end

      args << "url=#{url}" if url
      args
    end

    private

    def build_fields
      result = fields.dup
      result["username"] = username if username
      result["password"] = password || generate_password if should_have_password?
      result
    end

    def should_have_password?
      category == "login"
    end

    def generate_password
      # Generate a secure password: 24 chars, base64-like
      SecureRandom.base64(24)
    end

    def infer_type(label)
      label_lower = label.to_s.downcase

      case label_lower
      when /password|secret|key/
        "concealed"
      when /url/
        "url"
      when /otp|totp/
        "otp"
      else
        "text"
      end
    end
  end
end
