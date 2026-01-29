#!/bin/bash
# GCP Service Account Setup Commands
#
# Run these commands to create a service account with Monitoring Viewer role
# Replace YOUR_PROJECT_ID with your actual GCP project ID
#
# Prerequisites:
# - gcloud CLI installed: https://cloud.google.com/sdk/docs/install
# - Authenticated with gcloud: gcloud auth login
# - Project ID set: gcloud config set project YOUR_PROJECT_ID

# Step 1: Set your project ID (replace with your actual project ID)
export PROJECT_ID="your-gcp-project-id"
gcloud config set project $PROJECT_ID

# Step 2: Enable Cloud Monitoring API (if not already enabled)
gcloud services enable monitoring.googleapis.com

# Step 3: Create service account
gcloud iam service-accounts create monitoring-readonly \
  --display-name="Monitoring Read-Only" \
  --description="Service account for external monitoring system (read-only Cloud Monitoring access)" \
  --project=$PROJECT_ID

# Step 4: Grant Monitoring Viewer role (read-only access to Cloud Monitoring)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/monitoring.viewer" \
  --condition=None

# Step 5: Create and download JSON key
# This key will be used by the Stackdriver Exporter
gcloud iam service-accounts keys create ./configs/gcp-service-account-key.json \
  --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com \
  --project=$PROJECT_ID

# Step 6: Verify service account was created
gcloud iam service-accounts describe monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com

# Step 7: Verify key file was created
ls -la ./configs/gcp-service-account-key.json

# Expected output:
# -rw------- 1 user user 2345 Jan 28 12:00 ./configs/gcp-service-account-key.json

# Security: The key file contains sensitive credentials
# - It's already in .gitignore
# - Store it securely
# - Rotate keys every 90 days
# - Delete old keys from GCP Console

# Next: Add PROJECT_ID to .env file
# GCP_PROJECT_ID=your-gcp-project-id
