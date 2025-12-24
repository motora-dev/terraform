# Cloud Run Service
resource "google_cloud_run_v2_service" "main" {
  name                = "${var.service_name}-${var.environment}"
  location            = var.region
  project             = var.project_id
  deletion_protection = false

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.container_image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }

        cpu_idle = true # Enable CPU throttling during idle
      }

      # Environment variables
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables
      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_name
              version = env.value.version
            }
          }
        }
      }

      # Health check
      dynamic "liveness_probe" {
        for_each = var.health_check_path != "" ? [1] : []
        content {
          http_get {
            path = var.health_check_path
          }
          initial_delay_seconds = 30
          period_seconds        = 30
          timeout_seconds       = 3
          failure_threshold     = 3
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      scaling, # Ignore GCP-managed scaling defaults
    ]
  }
}

# IAM binding for public access (if needed)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

