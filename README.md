# Terraform Infrastructure

Centralized Terraform repository for managing GCP infrastructure across multiple applications.

## Structure

```
terraform/
├── main.tf                    # Main configuration (single tfstate)
├── variables.tf               # Variable definitions
├── versions.tf                # Provider versions
├── outputs.tf                 # Output definitions
├── environments/              # Environment-specific tfvars
│   ├── develop.tfvars
│   ├── preview.tfvars
│   └── main.tfvars
├── packages/
│   └── common/                # Shared Terraform modules
│       ├── iam/               # Service accounts & IAM
│       ├── wif/               # Workload Identity Federation
│       ├── secrets/           # Secret Manager
│       └── cloud-run/         # Cloud Run (optional)
└── apps/                      # Application documentation
    ├── angular-nestjs-realworld-example-app/
    │   └── secrets.md
    └── motora-dev/
        └── secrets.md
```

## Prerequisites

- Terraform >= 1.12.0
- Google Cloud CLI

## Getting Started

```bash
# Initialize Terraform
terraform init

# Plan for development environment
terraform plan -var-file=environments/develop.tfvars

# Apply for development environment
terraform apply -var-file=environments/develop.tfvars
```

## Environment Configuration

Environment-specific configurations are stored in `environments/`:

| File             | Description                 |
| ---------------- | --------------------------- |
| `develop.tfvars` | Development environment     |
| `preview.tfvars` | Preview/staging environment |
| `main.tfvars`    | Production environment      |

Copy the example file and fill in the values:

```bash
cp environments/develop.tfvars.example environments/develop.tfvars
# Edit develop.tfvars with your values
```

## Services

All services are managed in a single tfstate to avoid conflicts:

```hcl
services = {
  "realworld" = {
    github_org   = "motora-dev"
    github_repo  = "angular-nestjs-realworld-example-app"
    secret_names = ["database-url", "cors-origins", ...]
  }
  "motora-dev" = {
    github_org   = "motora-dev"
    github_repo  = "motora-dev"
    secret_names = ["database-url", "supabase-url", ...]
  }
}
```

## Modules

### IAM (`packages/common/iam`)

Creates service accounts for:

- GitHub Actions (CI/CD)
- Cloud Run
- Vercel (optional)

### WIF (`packages/common/wif`)

Sets up Workload Identity Federation for secure GitHub Actions authentication.

### Secrets (`packages/common/secrets`)

Manages secrets in Google Secret Manager with service name prefix.

### Cloud Run (`packages/common/cloud-run`)

Optional module for managing Cloud Run services via Terraform.

## Outputs

After applying, you can get the outputs for configuring GitHub Actions:

```bash
# Get all outputs
terraform output

# Get GitHub Secrets setup for a specific service
terraform output -json github_secrets_setup | jq '.realworld'
```
