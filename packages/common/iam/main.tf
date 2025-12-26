# Service Account for GitHub Actions (optional, for backward compatibility)
resource "google_service_account" "github_actions" {
  count = var.create_github_actions_sa ? 1 : 0

  account_id   = "${var.service_name}-gh"
  display_name = "GitHub Actions SA - ${var.service_name}"
  description  = "Service account for GitHub Actions to deploy ${var.service_name} to Cloud Run"
  project      = var.project_id
}

# Service Account for Cloud Run
resource "google_service_account" "cloud_run" {
  account_id   = "${var.service_name}-cr"
  display_name = "Cloud Run SA - ${var.service_name}"
  description  = "Service account for Cloud Run service"
  project      = var.project_id
}

# IAM roles for GitHub Actions service account (only if created)
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
  for_each = var.create_github_actions_sa ? toset(local.github_actions_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

# Allow GitHub Actions to act as Cloud Run service account (only if GitHub Actions SA is created)
resource "google_service_account_iam_member" "github_actions_act_as_cloud_run" {
  count = var.create_github_actions_sa ? 1 : 0

  service_account_id = google_service_account.cloud_run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_actions[0].email}"
}

# IAM roles for Cloud Run service account (minimal permissions)
locals {
  cloud_run_roles = [
    "roles/cloudsql.client",              # Cloud SQL access (if needed)
    "roles/secretmanager.secretAccessor", # Secret Manager access
  ]
}

resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset(local.cloud_run_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}
