# chore: migrate terraform to centralized repository

## Overview

This PR consolidates Terraform infrastructure configurations into a centralized repository. It includes major improvements to IAM and Workload Identity Federation (WIF) setup for better resource management and reduced complexity.

## Key Changes

### 🔧 GitHub IAM Consolidation

**Before:**

- Each service had its own Workload Identity Pool and Provider
- Each service had its own GitHub Actions Service Account
- Example: `realworld-pool`, `motora-dev-pool`, `realworld-gh`, `motora-dev-gh`

**After:**

- **Single project-level Workload Identity Pool/Provider** (`github-actions-pool`, `github-actions-prov`)
- **Single project-level GitHub Actions Service Account** (`github-actions`)
- **Multiple repositories supported** via a single Provider with repository-based access control

### 📦 Architecture Improvements

1. **Centralized GitHub Authentication**

   - All services share one Workload Identity Pool/Provider
   - Repository access is controlled via `attribute_condition` with OR logic
   - Easier management and fewer resources to maintain

2. **Service-Specific Cloud Run Service Accounts**

   - Each service maintains its own Cloud Run Service Account (e.g., `realworld-cr`, `motora-dev-cr`)
   - The unified GitHub Actions Service Account can impersonate any Cloud Run Service Account
   - Maintains service isolation while simplifying CI/CD setup

3. **Multi-Repository Support**
   - Provider accepts multiple repositories: `motora-dev/angular-nestjs-realworld-example-app`, `motora-dev/motora-dev`
   - Access control via attribute conditions: `assertion.repository == 'org/repo1' || assertion.repository == 'org/repo2'`
   - IAM bindings created per repository for fine-grained access

## Modified Files

### Core Infrastructure

- `main.tf` - Added project-level GitHub Actions Service Account and unified WIF module
- `outputs.tf` - Updated to reflect unified WIF provider (shared across all services)

### Modules

- `packages/common/wif/`
  - `main.tf` - Refactored to support multiple repositories and multiple Cloud Run Service Accounts
  - `variables.tf` - Updated variables: `github_repositories` (list), `cloud_run_service_account_emails` (list)
- `packages/common/iam/`
  - `main.tf` - Made GitHub Actions Service Account creation optional (controlled by `create_github_actions_sa` flag)
  - `variables.tf` - Added `create_github_actions_sa` flag (default: `false`)
  - `outputs.tf` - Updated to handle optional GitHub Actions Service Account

### Application Modules

- `apps/*/main.tf` - Updated to reference unified GitHub Actions Service Account

## Migration Notes

### For Existing Environments

If you have existing Workload Identity Pool/Provider resources that need to be imported:

1. **Import existing WIF resources** (if any exist):

   ```bash
   terraform import -var-file=environments/{env}.tfvars 'module.wif.google_iam_workload_identity_pool.github' projects/{project_id}/locations/global/workloadIdentityPools/github-actions-pool
   terraform import -var-file=environments/{env}.tfvars 'module.wif.google_iam_workload_identity_pool_provider.github' projects/{project_id}/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-prov
   ```

2. **Import existing secrets** (if needed):
   ```bash
   terraform import -var-file=environments/{env}.tfvars 'google_secret_manager_secret.global_secrets["secret-name"]' projects/{project_id}/secrets/secret-name
   ```

### GitHub Actions Configuration

**Before:**

- Each repository had separate `WIF_PROVIDER` and `WIF_SERVICE_ACCOUNT` values
- Example: `realworld` and `motora-dev` had different providers

**After:**

- All repositories use the same `WIF_PROVIDER` and `WIF_SERVICE_ACCOUNT`
- Get unified values:
  ```bash
  terraform output -json github_secrets_setup
  ```

### Output Changes

**Before:**

```json
{
  "realworld": {
    "WIF_PROVIDER": "projects/.../workloadIdentityPools/realworld-pool/providers/realworld-prov",
    "WIF_SERVICE_ACCOUNT": "realworld-gh@..."
  },
  "motora-dev": {
    "WIF_PROVIDER": "projects/.../workloadIdentityPools/motora-dev-pool/providers/motora-dev-prov",
    "WIF_SERVICE_ACCOUNT": "motora-dev-gh@..."
  }
}
```

**After:**

```json
{
  "WIF_PROVIDER": "projects/.../workloadIdentityPools/github-actions-pool/providers/github-actions-prov",
  "WIF_SERVICE_ACCOUNT": "github-actions@..."
}
```

## Benefits

1. **Reduced Resource Count**: Fewer IAM resources to manage (2 pools → 1 pool, 2 providers → 1 provider, 2 GitHub SAs → 1 SA)
2. **Simplified Management**: Single point of configuration for GitHub authentication
3. **Better Scalability**: Easy to add new repositories without creating new pools/providers
4. **Maintained Isolation**: Cloud Run Service Accounts remain service-specific for security

## Testing

- [x] Tested with `develop` environment
- [x] Verified WIF provider accepts multiple repositories
- [x] Confirmed GitHub Actions Service Account can impersonate all Cloud Run Service Accounts
- [x] Validated outputs return unified values

## Breaking Changes

⚠️ **GitHub Actions workflows must be updated** to use the new unified `WIF_PROVIDER` and `WIF_SERVICE_ACCOUNT` values from `terraform output github_secrets_setup`.

## Related Issues

- Consolidates IAM resources for better management
- Addresses resource proliferation concerns
