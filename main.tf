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

# IAM module for each service (Cloud Run Service Account only)
module "iam" {
  for_each = var.services
  source   = "./packages/common/iam"

  project_id             = var.project_id
  service_name           = each.key
  create_github_actions_sa = false

  depends_on = [google_project_service.apis]
}

# Collect all GitHub repositories and Cloud Run service accounts
locals {
  github_repositories = [
    for service_name, service in var.services : "${service.github_org}/${service.github_repo}"
  ]
  cloud_run_service_account_emails = [
    for service_name, _ in var.services : module.iam[service_name].cloud_run_service_account_email
  ]
  github_org = var.services[keys(var.services)[0]].github_org
}

# Project-level GitHub Actions Service Account
resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions"
  description  = "Service account for GitHub Actions to deploy services to Cloud Run"
  project      = var.project_id
}

# IAM roles for GitHub Actions service account
locals {
  github_actions_roles = [
    "roles/run.admin",                 # Cloud Run admin
    "roles/storage.admin",             # Container Registry access
    "roles/cloudbuild.builds.builder", # Cloud Build
    "roles/iam.serviceAccountUser",    # Act as service account
    "roles/viewer",                    # Project Viewer
  ]
}

resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset(local.github_actions_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"

  depends_on = [google_service_account.github_actions]
}

# Workload Identity Federation module (project-level, single instance)
module "wif" {
  source = "./packages/common/wif"

  project_id                     = var.project_id
  github_org                     = local.github_org
  github_repositories            = local.github_repositories
  github_service_account_email   = google_service_account.github_actions.email
  cloud_run_service_account_emails = local.cloud_run_service_account_emails

  depends_on = [
    module.iam,
    google_service_account.github_actions,
    google_project_iam_member.github_actions_roles,
  ]
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
# L2: Service Secrets (service-specific, with service prefix)
# Example: realworld-database-url
# =============================================================================

locals {
  service_secrets = flatten([
    for service_name, service in var.services : [
      for secret_name in service.secret_names : {
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

resource "google_secret_manager_secret_iam_member" "service_secrets_access" {
  for_each = { for s in local.service_secrets : s.key => s }

  project   = var.project_id
  secret_id = google_secret_manager_secret.service_secrets[each.key].secret_id
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
        service_name       = service_name
        cloud_run_name     = cr_name
        config             = cr_config
        service_common_env = service.common_env_vars
        secret_names       = service.secret_names
        cloud_run_sa_email = module.iam[service_name].cloud_run_service_account_email
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

  # Secret environment variables with 2-tier naming:
  # - L1 (global_secret_names): use name as-is (e.g., "basic-auth-user")
  # - L2 (secret_names): add service prefix (e.g., "realworld-database-url")
  secret_env_vars = {
    for env_name, secret_name in each.value.config.secret_env_vars : env_name => {
      secret_name = (
        contains(var.global_secret_names, secret_name) ? secret_name :
        "${each.value.service_name}-${secret_name}"
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
  service_name                         = "realworld"
  github_actions_service_account_email = google_service_account.github_actions.email
  cloud_run_service_account_email      = module.iam["realworld"].cloud_run_service_account_email

  depends_on = [module.iam, module.wif, google_service_account.github_actions]
}

# motora-dev specific resources
module "app_motora" {
  source = "./apps/motora-dev"

  project_id                           = var.project_id
  region                               = var.region
  service_name                         = "motora-dev"
  github_actions_service_account_email = google_service_account.github_actions.email
  cloud_run_service_account_email      = module.iam["motora-dev"].cloud_run_service_account_email

  depends_on = [module.iam, module.wif, google_service_account.github_actions]
}
