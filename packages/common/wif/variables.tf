variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repositories" {
  description = "List of GitHub repositories in format 'org/repo'"
  type        = list(string)
}

variable "github_service_account_email" {
  description = "Service account email for GitHub Actions"
  type        = string
}

variable "cloud_run_service_account_emails" {
  description = "List of Cloud Run service account emails that GitHub Actions can act as"
  type        = list(string)
  default     = []
}
