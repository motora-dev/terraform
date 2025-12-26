output "github_actions_service_account_email" {
  description = "Email of the GitHub Actions service account"
  value       = var.create_github_actions_sa ? google_service_account.github_actions[0].email : null
}

output "cloud_run_service_account_email" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.cloud_run.email
}

