provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs (once per project)
resource "google_project_service" "apis" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "containerregistry.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  service = each.value
  project = var.project_id

  disable_on_destroy = false
}

# IAM module for each service
module "iam" {
  for_each = var.services
  source   = "./packages/common/iam"

  project_id   = var.project_id
  environment  = var.environment
  service_name = each.key

  depends_on = [google_project_service.apis]
}

# Workload Identity Federation module for each service
module "wif" {
  for_each = var.services
  source   = "./packages/common/wif"

  project_id                = var.project_id
  environment               = var.environment
  service_name              = each.key
  github_org                = each.value.github_org
  github_repo               = each.value.github_repo
  github_service_account_id = module.iam[each.key].github_actions_service_account_email

  depends_on = [module.iam]
}

# =============================================================================
# L1: Global Secrets (shared by all environments and services, no prefix)
# Example: basic-auth-user
# =============================================================================

resource "google_secret_manager_secret" "global_secrets" {
  for_each = toset(var.global_secret_names)

  secret_id = each.value
  project   = var.project_id

  labels = {
    level      = "global"
    managed_by = "terraform"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "global_secrets_initial" {
  for_each = toset(var.global_secret_names)

  secret      = google_secret_manager_secret.global_secrets[each.key].id
  secret_data = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_iam_member" "global_secrets_access" {
  for_each = {
    for pair in flatten([
      for secret_name in var.global_secret_names : [
        for service_name, service in var.services : {
          key         = "${secret_name}-${service_name}"
          secret_name = secret_name
          sa_email    = module.iam[service_name].cloud_run_service_account_email
        }
      ]
    ]) : pair.key => pair
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.global_secrets[each.value.secret_name].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.sa_email}"
}

# =============================================================================
# L2: Service-common Secrets (shared across environments, service-specific)
# Example: realworld-database-url
# =============================================================================

locals {
  service_secrets = flatten([
    for service_name, service in var.services : [
      for secret_name in service.service_secret_names : {
        key          = "${service_name}-${secret_name}"
        service_name = service_name
        secret_name  = secret_name
        full_name    = "${service_name}-${secret_name}"
        sa_email     = module.iam[service_name].cloud_run_service_account_email
      }
    ]
  ])
}

resource "google_secret_manager_secret" "service_secrets" {
  for_each = { for s in local.service_secrets : s.key => s }

  secret_id = each.value.full_name
  project   = var.project_id

  labels = {
    level        = "service"
    service_name = each.value.service_name
    managed_by   = "terraform"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "service_secrets_initial" {
  for_each = { for s in local.service_secrets : s.key => s }

  secret      = google_secret_manager_secret.service_secrets[each.key].id
  secret_data = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_iam_member" "service_secrets_access" {
  for_each = { for s in local.service_secrets : s.key => s }

  project   = var.project_id
  secret_id = google_secret_manager_secret.service_secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.sa_email}"
}

# =============================================================================
# L3: Environment-specific Secrets (environment + service prefix)
# Example: develop-realworld-cors-origins
# =============================================================================

locals {
  env_secrets = flatten([
    for service_name, service in var.services : [
      for secret_name in service.env_secret_names : {
        key          = "${service_name}-${secret_name}"
        service_name = service_name
        secret_name  = secret_name
        full_name    = "${var.environment}-${service_name}-${secret_name}"
        sa_email     = module.iam[service_name].cloud_run_service_account_email
      }
    ]
  ])
}

resource "google_secret_manager_secret" "env_secrets" {
  for_each = { for s in local.env_secrets : s.key => s }

  secret_id = each.value.full_name
  project   = var.project_id

  labels = {
    level        = "environment"
    environment  = var.environment
    service_name = each.value.service_name
    managed_by   = "terraform"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "env_secrets_initial" {
  for_each = { for s in local.env_secrets : s.key => s }

  secret      = google_secret_manager_secret.env_secrets[each.key].id
  secret_data = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [secret_data]
  }
}

resource "google_secret_manager_secret_iam_member" "env_secrets_access" {
  for_each = { for s in local.env_secrets : s.key => s }

  project   = var.project_id
  secret_id = google_secret_manager_secret.env_secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.sa_email}"
}

# =============================================================================
# Cloud Run Services
# =============================================================================

# Flatten Cloud Run services from all services
locals {
  cloud_run_services = merge([
    for service_name, service in var.services : {
      for cr_name, cr_config in service.cloud_run_services :
      "${service_name}-${cr_name}" => {
        service_name         = service_name
        cloud_run_name       = cr_name
        config               = cr_config
        service_common_env   = service.common_env_vars
        service_secret_names = service.service_secret_names
        env_secret_names     = service.env_secret_names
        cloud_run_sa_email   = module.iam[service_name].cloud_run_service_account_email
      }
    }
  ]...)
}

# Cloud Run module for each service
module "cloud_run" {
  for_each = local.cloud_run_services
  source   = "./packages/common/cloud-run"

  project_id            = var.project_id
  region                = var.region
  environment           = var.environment
  service_name          = each.key
  service_account_email = each.value.cloud_run_sa_email

  # Use placeholder image for initial deployment (GitHub Actions will update)
  container_image = "gcr.io/cloudrun/hello"

  # Scaling and resources
  min_instances         = each.value.config.min_instances
  max_instances         = each.value.config.max_instances
  cpu_limit             = each.value.config.cpu_limit
  memory_limit          = each.value.config.memory_limit
  allow_unauthenticated = each.value.config.allow_unauthenticated
  container_port        = each.value.config.container_port
  health_check_path     = each.value.config.health_check_path

  # Merge environment variables: global -> service common -> cloud run specific
  env_vars = merge(
    var.common_env_vars,
    each.value.service_common_env,
    each.value.config.env_vars
  )

  # Secret environment variables with 3-tier naming:
  # - L1 (global_secret_names): use name as-is (e.g., "basic-auth-user")
  # - L2 (service_secret_names): add service prefix (e.g., "realworld-database-url")
  # - L3 (env_secret_names): add environment + service prefix (e.g., "develop-realworld-cors-origins")
  secret_env_vars = {
    for env_name, secret_name in each.value.config.secret_env_vars : env_name => {
      secret_name = (
        contains(var.global_secret_names, secret_name) ? secret_name :
        contains(each.value.service_secret_names, secret_name) ? "${each.value.service_name}-${secret_name}" :
        "${var.environment}-${each.value.service_name}-${secret_name}"
      )
      version = "latest"
    }
  }

  depends_on = [
    module.iam,
    google_secret_manager_secret.global_secrets,
    google_secret_manager_secret_iam_member.global_secrets_access,
    google_secret_manager_secret.service_secrets,
    google_secret_manager_secret_iam_member.service_secrets_access,
    google_secret_manager_secret.env_secrets,
    google_secret_manager_secret_iam_member.env_secrets_access,
  ]
}

# =============================================================================
# Application-specific modules
# =============================================================================

# angular-nestjs-realworld-example-app specific resources
module "app_realworld" {
  source = "./apps/angular-nestjs-realworld-example-app"

  project_id                           = var.project_id
  region                               = var.region
  environment                          = var.environment
  service_name                         = "realworld"
  github_actions_service_account_email = module.iam["realworld"].github_actions_service_account_email
  cloud_run_service_account_email      = module.iam["realworld"].cloud_run_service_account_email

  depends_on = [module.iam, module.wif]
}

# motora-dev specific resources
module "app_motora" {
  source = "./apps/motora-dev"

  project_id                           = var.project_id
  region                               = var.region
  environment                          = var.environment
  service_name                         = "motora-dev"
  github_actions_service_account_email = module.iam["motora-dev"].github_actions_service_account_email
  cloud_run_service_account_email      = module.iam["motora-dev"].cloud_run_service_account_email

  depends_on = [module.iam, module.wif]
}

