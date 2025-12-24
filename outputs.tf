# Per-service outputs
output "services" {
  description = "Service configurations"
  value = {
    for service_name, _ in var.services : service_name => {
      github_actions_service_account = module.iam[service_name].github_actions_service_account_email
      cloud_run_service_account      = module.iam[service_name].cloud_run_service_account_email
      workload_identity_provider     = module.wif[service_name].provider_name
    }
  }
}

# GitHub Secrets setup for each service
output "github_secrets_setup" {
  description = "Values for GitHub Secrets per service"
  value = {
    for service_name, _ in var.services : service_name => {
      WIF_PROVIDER        = module.wif[service_name].provider_name
      WIF_SERVICE_ACCOUNT = module.iam[service_name].github_actions_service_account_email
    }
  }
}

# Cloud Run service URLs
output "cloud_run_urls" {
  description = "URLs of Cloud Run services"
  value = {
    for key, _ in local.cloud_run_services : key => module.cloud_run[key].service_url
  }
}

