# OpCreds - 1Password Credential Management CLI

A Ruby CLI tool for managing infrastructure credentials in 1Password, built with dry-cli.

## Overview

OpCreds provides a structured way to create, retrieve, rotate, and manage credentials for various infrastructure services (AWS, Proxmox, Kubernetes, etc.) stored in 1Password. It uses a provider-based architecture that makes it easy to add support for new service types.

## Dependencies

- Ruby (managed via mise)
- dry-cli gem
- 1Password CLI (`op`) - installed via mise

## Directory Structure

```
home/
├── .config/
│   ├── mise/conf.d/op.toml    # mise tool config for op CLI
│   └── zsh/op.zsh             # shell aliases and helper functions
└── .local/
    ├── bin/
    │   └── opcreds            # CLI entrypoint
    └── share/opcreds/
        ├── cli.rb             # dry-cli command definitions
        ├── config.rb          # Configuration management (~/.config/opcreds/config.yml)
        ├── credential.rb      # Credential model
        ├── op_client.rb       # Wrapper around `op` CLI (single entry point)
        ├── providers/         # Provider implementations
        │   ├── base.rb        # Base class with shared logic
        │   ├── generic.rb     # Generic provider for any service
        │   ├── aws.rb         # AWS IAM users, access keys
        │   └── proxmox.rb     # Proxmox VE credentials
        └── templates/         # ERB templates for policies, configs
            └── iam_credential_manager_policy.json.erb
```

## Usage

```bash
# Create credentials
opcreds create -p proxmox -s singapore -u root --url https://pve.sg.lab:8006
opcreds create -p aws -s singapore -S terraform -v AWS-Operations
opcreds create -p generic -s us --service traefik -u admin

# Retrieve credentials
opcreds get "Proxmox - Singapore"
opcreds get "AWS Singapore - terraform" -f "Access Key ID"
opcreds get "Proxmox - US" --format env

# List credentials
opcreds list -v HomeLab
opcreds list -p aws -s singapore

# Rotate credentials
opcreds rotate "Proxmox - Singapore"

# Configuration
opcreds config --list
opcreds config default_vault HomeLab
```

## Architecture

### OpClient

Single entry point for all 1Password CLI operations. Located in `op_client.rb`.

- Uses Singleton pattern for consistent state
- Returns `Result` structs with `success?`, `data`, `error`
- Supports debug mode via `OPCREDS_DEBUG=1`
- Handles field type inference (concealed, text, url, otp)

### Providers

Each provider inherits from `Providers::Base` and implements:

- `build_credential(options)` - Create a Credential instance from CLI options
- `rotate(existing_item)` - Rotate credentials for an existing item

Providers handle service-specific logic like:
- Field naming conventions
- Default vaults
- Rotation procedures
- API integration (where applicable)

### Configuration

Stored in `~/.config/opcreds/config.yml`. Supports:

- Default vaults per credential type
- Site definitions with aliases and AWS regions
- Dot notation for nested keys (`opcreds config sites.singapore.aws_region`)

## Shell Integration

The `op.zsh` file provides:

- `opc` - alias for opcreds
- `opget`, `opnew`, `opls` - quick access functions
- `openv` - load a single secret into an environment variable
- `opsource` - inject secrets from a template file into environment

## Adding New Providers

1. Create `providers/<name>.rb`
2. Inherit from `Providers::Base`
3. Implement `build_credential` and `rotate`
4. Add to the factory in `providers/base.rb`

```ruby
# providers/example.rb
module OpCreds
  module Providers
    class Example < Base
      def build_credential(options)
        Credential.new(
          title: build_title("Example", options[:site]),
          vault: options[:vault] || config.vault_for(:default),
          tags: build_tags("example", options[:site]),
          # ... fields specific to this provider
        )
      end

      def rotate(existing_item)
        # Provider-specific rotation logic
      end
    end
  end
end
```

## Vault Organization

Recommended vault structure:

```
AWS-Bootstrap/          # Root accounts, bootstrap credentials (rarely accessed)
AWS-Operations/         # Day-to-day AWS service credentials
HomeLab/               # Infrastructure credentials (Proxmox, K8s, etc.)
```

## Environment Variables

- `OPCREDS_DEBUG=1` - Enable debug output showing op commands

## Testing

```bash
# Dry run to see what would be created
opcreds create -p proxmox -s singapore --dry-run

# Check op CLI is working
op whoami
```
