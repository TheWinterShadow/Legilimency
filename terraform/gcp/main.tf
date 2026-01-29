# GCP Terraform Configuration for Monitoring Service Account
# Creates a read-only service account for Cloud Monitoring

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.17"
    }
  }
}

# Configure the Google Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables
variable "project_id" {
  description = "GCP Project ID to create the service account in"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "service_account_name" {
  description = "Name of the service account"
  type        = string
  default     = "monitoring-readonly"
}

# Enable required APIs
resource "google_project_service" "monitoring" {
  project = var.project_id
  service = "monitoring.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Service Account for monitoring
resource "google_service_account" "monitoring" {
  account_id   = var.service_account_name
  display_name = "Monitoring Read-Only"
  description  = "Read-only access for external monitoring system (Raspberry Pi + Grafana Cloud)"
  project      = var.project_id
}

# Grant Monitoring Viewer role
resource "google_project_iam_member" "monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.monitoring.email}"

  depends_on = [google_project_service.monitoring]
}

# Create service account key
resource "google_service_account_key" "monitoring" {
  service_account_id = google_service_account.monitoring.name
  key_algorithm      = "KEY_ALG_RSA_2048"
}

# Local file for the service account key
resource "local_file" "service_account_key" {
  content         = base64decode(google_service_account_key.monitoring.private_key)
  filename        = "${path.module}/../../configs/gcp-service-account-key.json"
  file_permission = "0600"
}
