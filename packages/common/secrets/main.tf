# Secrets management using Google Secret Manager

# Add environment and service_name prefix to secret names
locals {
  secrets = {
    for name in var.secret_names : name => "${var.environment}-${var.service_name}-${name}"
  }
}

resource "google_secret_manager_secret" "secrets" {
  for_each = local.secrets

  secret_id = each.value
  project   = var.project_id

  labels = {
    environment  = var.environment
    service_name = var.service_name
    managed_by   = "terraform"
  }

  replication {
    auto {}
  }
}

# Create initial placeholder version for secrets
resource "google_secret_manager_secret_version" "secrets_initial" {
  for_each = local.secrets

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# Grant Cloud Run service account access to secrets
resource "google_secret_manager_secret_iam_member" "cloud_run_secrets" {
  for_each = local.secrets

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.cloud_run_service_account_email}"
}

