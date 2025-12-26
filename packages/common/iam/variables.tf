variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
}

variable "create_github_actions_sa" {
  description = "Whether to create GitHub Actions service account"
  type        = bool
  default     = false
}
