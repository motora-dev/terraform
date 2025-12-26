# Build repository condition for attribute_condition
locals {
  repository_conditions = join(" || ", [
    for repo in var.github_repositories : "assertion.repository == '${repo}'"
  ])
}

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions"
  description               = "WIF Pool for GitHub Actions"
  project                   = var.project_id
}

# Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-prov"
  display_name                       = "GitHub Actions"
  description                        = "WIF Provider for GitHub Actions"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.actor"       = "assertion.actor"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
  }

  attribute_condition = local.repository_conditions

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub Actions to impersonate the GitHub Actions service account
# Create IAM binding for each repository
resource "google_service_account_iam_member" "github_actions_wi" {
  for_each = toset(var.github_repositories)

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.github_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository/${each.value}"
}

# Allow GitHub Actions service account to act as each Cloud Run service account
resource "google_service_account_iam_member" "github_actions_act_as_cloud_run" {
  for_each = toset(var.cloud_run_service_account_emails)

  service_account_id = "projects/${var.project_id}/serviceAccounts/${each.value}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.github_service_account_email}"
}

# Get project number
data "google_project" "current" {
  project_id = var.project_id
}
