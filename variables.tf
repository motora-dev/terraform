variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "asia-northeast1"
}

# Common environment variables for all services
variable "common_env_vars" {
  description = "Environment variables shared by all Cloud Run services"
  type        = map(string)
  default     = {}
}

# L1: Global secrets (NO prefix, shared across all environments and services)
# Example: basic-auth-user
variable "global_secret_names" {
  description = "Secret names shared by all environments and services"
  type        = list(string)
  default     = []
}

variable "services" {
  description = "Map of services to deploy"
  type = map(object({
    github_org  = string
    github_repo = string

    # L2: Service secrets (with service prefix)
    # Example: realworld-database-url
    secret_names = optional(list(string), [])

    # Common environment variables for this service (applied to all Cloud Run services)
    common_env_vars = optional(map(string), {})

    # Cloud Run services configuration
    cloud_run_services = optional(map(object({
      allow_unauthenticated = optional(bool, true)
      min_instances         = optional(number, 0)
      max_instances         = optional(number, 10)
      cpu_limit             = optional(string, "1")
      memory_limit          = optional(string, "512Mi")
      container_port        = optional(number, 8080)
      health_check_path     = optional(string, "/health")

      # Environment variables specific to this Cloud Run service
      env_vars = optional(map(string), {})

      # Secret environment variables (key = env var name, value = secret name without service prefix)
      secret_env_vars = optional(map(string), {})
    })), {})
  }))
}
