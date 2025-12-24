variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Service name for secret prefix"
  type        = string
}

variable "secret_names" {
  description = "List of secret names to create (without prefix)"
  type        = list(string)
}

variable "cloud_run_service_account_email" {
  description = "Cloud Run service account email"
  type        = string
}

