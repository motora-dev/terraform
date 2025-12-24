# Application-specific resources for motora-dev
#
# Add any resources that are unique to this application here.
# Common resources (IAM, WIF, Secrets) are managed in the root main.tf.
#
# Available variables:
#   - var.project_id
#   - var.region
#   - var.environment
#   - var.service_name
#   - var.github_actions_service_account_email
#   - var.cloud_run_service_account_email

# Example: Application-specific Cloud Storage bucket
# resource "google_storage_bucket" "app_assets" {
#   name     = "${var.service_name}-assets-${var.environment}"
#   location = var.region
#   project  = var.project_id
# }

