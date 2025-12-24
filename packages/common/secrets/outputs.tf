output "secret_ids" {
  description = "Map of secret IDs (key: base name, value: full secret ID with prefix)"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.secret_id
  }
}

output "secret_names" {
  description = "Map of secret names (key: base name, value: full resource name)"
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.name
  }
}

