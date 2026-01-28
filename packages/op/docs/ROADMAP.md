# OpCreds Roadmap

Future features and provider implementations for the opcreds CLI.

---

## Planned Providers

### Kubernetes

**Priority:** High  
**Complexity:** Medium

Support for Kubernetes cluster credentials and service accounts.

**Features:**
- Store kubeconfig credentials (client cert, token, etc.)
- Service account token management
- Context-aware credential retrieval
- Integration with kubectl config

**Fields:**
- Cluster URL / API Server
- CA Certificate (or reference)
- Client Certificate
- Client Key
- Bearer Token
- Namespace (default)
- Context Name

**Rotation:**
- Service account token refresh
- Client certificate renewal (requires cert-manager integration)

**Usage:**
```bash
opcreds create -p kubernetes -s singapore --service production \
  --url https://k8s.sg.lab:6443

# Export kubeconfig snippet
opcreds get "Kubernetes - Singapore - production" --format kubeconfig
```

---

### Traefik

**Priority:** High  
**Complexity:** Low

Traefik reverse proxy dashboard and API credentials.

**Features:**
- Dashboard basic auth credentials
- API token management
- Per-entrypoint credential support

**Fields:**
- Dashboard URL
- Username
- Password (htpasswd compatible)
- API Token (if using token auth)

**Rotation:**
- Generate new password, output htpasswd format for traefik config

**Usage:**
```bash
opcreds create -p traefik -s singapore -u admin \
  --url https://traefik.sg.lab/dashboard/

# Get htpasswd format for dynamic config
opcreds get "Traefik - Singapore" --format htpasswd
```

---

### Cloudflare

**Priority:** Medium  
**Complexity:** Medium

Cloudflare API tokens and zone management.

**Features:**
- Global API key storage (legacy)
- Scoped API token management
- Zone-specific tokens
- Origin certificates

**Fields:**
- Account ID
- API Token (scoped)
- Global API Key (legacy, discouraged)
- Email (for legacy API)
- Zone ID (optional, for zone-scoped tokens)
- Token Permissions (documentation field)

**Rotation:**
- API token rotation via Cloudflare API
- Requires cloudflare gem or API calls

**Usage:**
```bash
opcreds create -p cloudflare -s singapore --service dns-management \
  --account-id abc123

# For zone-specific token
opcreds create -p cloudflare -s singapore --service zone-ssl \
  --zone-id xyz789
```

**Integration opportunities:**
- `cloudflare` gem for API operations
- Terraform cloudflare provider credential injection

---

### Google Cloud Platform (GCP)

**Priority:** Medium  
**Complexity:** High

GCP service account and API credential management.

**Features:**
- Service account key storage (JSON keyfile)
- Application default credentials setup
- Project-scoped credentials
- Workload identity references

**Fields:**
- Project ID
- Service Account Email
- Key ID
- Private Key (JSON keyfile content or reference)
- Key Type (JSON, P12)
- Scopes (documentation)

**Rotation:**
- Create new service account key via GCP API
- Delete old key after grace period
- Requires google-cloud-iam gem

**Usage:**
```bash
opcreds create -p gcp -s singapore --service terraform \
  --project-id my-project-123

# Import existing service account key
opcreds create -p gcp -s singapore --service app-engine \
  --keyfile ~/path/to/sa-key.json

# Export for GOOGLE_APPLICATION_CREDENTIALS
opcreds get "GCP - Singapore - terraform" --format keyfile > /tmp/gcp-key.json
```

**Special considerations:**
- JSON keyfiles are multi-line, need proper storage
- Consider storing as secure note or document attachment
- Integration with `gcloud auth activate-service-account`

---

### DigitalOcean

**Priority:** Low  
**Complexity:** Low

DigitalOcean API tokens and Spaces credentials.

**Features:**
- Personal access token management
- Spaces (S3-compatible) access keys
- App Platform tokens

**Fields:**
- API Token (Personal Access Token)
- Spaces Access Key ID
- Spaces Secret Key
- Spaces Region
- Spaces Endpoint URL

**Rotation:**
- API token rotation via DO API
- Spaces key rotation

**Usage:**
```bash
# API token
opcreds create -p digitalocean -s singapore --service api

# Spaces credentials
opcreds create -p digitalocean -s singapore --service spaces \
  --spaces-region sgp1
```

---

## Core Features Roadmap

### Phase 1: Foundation (Current)
- [x] Basic CLI with dry-cli
- [x] OpClient wrapper for `op` CLI
- [x] Provider architecture
- [x] Generic, AWS, Proxmox providers
- [x] Configuration management
- [x] Shell integration

### Phase 2: Enhanced Providers
- [ ] Kubernetes provider
- [ ] Traefik provider
- [ ] Output format options (env, json, kubeconfig, htpasswd)
- [ ] Credential templates

### Phase 3: Cloud Providers
- [ ] Cloudflare provider
- [ ] GCP provider
- [ ] DigitalOcean provider
- [ ] Azure provider (future)

### Phase 4: Automation
- [ ] AWS SDK integration for IAM operations
- [ ] Automated rotation scheduling
- [ ] Ansible integration (lookup plugin)
- [ ] Terraform integration (data source)

### Phase 5: Advanced Features
- [ ] Credential dependencies (rotate A, then B)
- [ ] Audit logging
- [ ] Expiration tracking and alerts
- [ ] Team/shared credential workflows
- [ ] 1Password Connect server support

---

## Feature Ideas

### Output Formats

Extend `--format` option across all providers:

| Format | Description | Use Case |
|--------|-------------|----------|
| `text` | Human-readable (default) | Interactive use |
| `json` | JSON object | Scripting, jq |
| `env` | KEY=value pairs | Shell sourcing |
| `export` | export KEY=value | Direct shell eval |
| `kubeconfig` | Kubernetes config snippet | kubectl |
| `htpasswd` | Apache htpasswd format | Traefik, nginx |
| `keyfile` | Full credential file | GCP service accounts |
| `tf` | Terraform tfvars | IaC |

### Credential Templates

Define reusable credential structures:

```yaml
# ~/.config/opcreds/templates/lab-service.yml
category: login
vault: HomeLab
tags:
  - infrastructure
  - "{{ site }}"
  - "{{ provider }}"
fields:
  - label: Environment
    value: "{{ site }}"
  - label: Managed By
    value: opcreds
```

```bash
opcreds create --template lab-service -p traefik -s singapore
```

### Bulk Operations

```bash
# Create credentials from YAML manifest
opcreds apply -f credentials.yml

# Export all credentials for a site
opcreds export -s singapore > singapore-creds.yml

# Rotate all credentials for a provider
opcreds rotate --provider aws --all
```

### Integration Hooks

```yaml
# ~/.config/opcreds/hooks.yml
post_create:
  aws:
    - notify-slack "New AWS credential created: {{ title }}"
post_rotate:
  proxmox:
    - ansible-playbook update-proxmox-password.yml -e "host={{ site }}"
```

### Ansible Lookup Plugin

```yaml
# In Ansible playbook
- name: Configure service
  template:
    src: config.j2
    dest: /etc/myservice/config.yml
  vars:
    db_password: "{{ lookup('opcreds', 'Proxmox - Singapore', field='password') }}"
```

### Terraform Data Source

```hcl
data "opcreds_credential" "proxmox" {
  title = "Proxmox - Singapore"
  vault = "HomeLab"
}

resource "proxmox_vm" "example" {
  # ...
  password = data.opcreds_credential.proxmox.password
}
```

---

## Provider Implementation Checklist

When adding a new provider:

- [ ] Create `providers/<name>.rb`
- [ ] Inherit from `Providers::Base`
- [ ] Implement `build_credential(options)`
- [ ] Implement `rotate(existing_item)`
- [ ] Add to factory in `providers/base.rb`
- [ ] Add provider-specific CLI options (if needed)
- [ ] Add ERB templates (if needed)
- [ ] Document fields and usage
- [ ] Add to this roadmap
- [ ] Update CLAUDE.md

---

## Contributing

To propose a new provider or feature:

1. Open an issue describing the use case
2. Draft the field schema and rotation strategy
3. Consider API/SDK requirements
4. Implement following the provider checklist
