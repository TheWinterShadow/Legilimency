# Output values for GCP monitoring setup

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.monitoring.email
}

output "service_account_name" {
  description = "Fully qualified name of the service account"
  value       = google_service_account.monitoring.name
}

output "service_account_id" {
  description = "Unique ID of the service account"
  value       = google_service_account.monitoring.unique_id
}

output "key_file_path" {
  description = "Path to the service account key file"
  value       = local_file.service_account_key.filename
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

# Instructions for using the service account
output "instructions" {
  description = "Instructions for using the service account"
  value       = <<-EOT

    ========================================
    GCP Service Account Created Successfully
    ========================================

    The service account key has been saved to:
    ${local_file.service_account_key.filename}

    Add these values to your .env file:

    GCP_PROJECT_ID=${var.project_id}
    GCP_KEY_PATH=./configs/gcp-service-account-key.json

    IMPORTANT:
    - The key file contains sensitive credentials
    - Never commit it to git
    - Rotate the key every 90 days

    To verify the service account:
    gcloud auth activate-service-account --key-file=${local_file.service_account_key.filename}
    gcloud monitoring metrics list --limit=5

  EOT
}
