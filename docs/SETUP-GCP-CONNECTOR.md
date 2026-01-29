# GCP Connector Setup Guide

This guide walks you through creating a service account with minimal permissions for Cloud Monitoring.

## Overview

The GCP connector (Stackdriver Exporter) needs read-only access to:

- Cloud Monitoring API (for metric data)
- Project metadata (for resource discovery)

## Security Principles

- **Monitoring Viewer role only**: No ability to modify anything
- **Project-scoped**: Access limited to specific project(s)
- **Service account key**: Stored securely, rotated periodically

## Prerequisites

- GCP account with a project
- `gcloud` CLI installed (optional but recommended)
- Owner or IAM Admin role on the project

## Option A: GCP Console Setup

### Step 1: Enable Cloud Monitoring API

1. Go to: https://console.cloud.google.com/apis/library
2. Search for "Cloud Monitoring API"
3. Click on it
4. Click **Enable** (if not already enabled)

### Step 2: Create Service Account

1. Go to: https://console.cloud.google.com/iam-admin/serviceaccounts
2. Select your project
3. Click **Create Service Account**
4. Service account details:
   - Name: `monitoring-readonly`
   - ID: `monitoring-readonly` (auto-generated)
   - Description: `Read-only access for external monitoring system`
5. Click **Create and Continue**

### Step 3: Grant Permissions

1. In the "Grant this service account access to project" section
2. Click **Select a role**
3. Search for and select: `Monitoring Viewer`
4. Click **Continue**
5. Skip "Grant users access to this service account"
6. Click **Done**

### Step 4: Create Key

1. Click on the newly created service account
2. Go to **Keys** tab
3. Click **Add Key** → **Create new key**
4. Select **JSON**
5. Click **Create**
6. The key file downloads automatically

⚠️ **Important**: Store this key file securely. It provides access to your GCP project.

### Step 5: Move Key to Project

```bash
# Move the downloaded key to your project
mv ~/Downloads/your-project-abc123.json \
   ~/raspberry-pi-monitoring/configs/gcp-service-account-key.json

# Secure the file
chmod 600 ~/raspberry-pi-monitoring/configs/gcp-service-account-key.json
```

## Option B: gcloud CLI Setup

### Prerequisites

```bash
# Install gcloud CLI
# See: https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

### Create Service Account

```bash
# Set your project ID
PROJECT_ID="your-gcp-project-id"

# Enable Cloud Monitoring API
gcloud services enable monitoring.googleapis.com --project=$PROJECT_ID

# Create service account
gcloud iam service-accounts create monitoring-readonly \
  --display-name="Monitoring Read-Only" \
  --description="Read-only access for external monitoring system" \
  --project=$PROJECT_ID

# Grant Monitoring Viewer role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/monitoring.viewer"

# Create and download key
gcloud iam service-accounts keys create configs/gcp-service-account-key.json \
  --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com

# Secure the file
chmod 600 configs/gcp-service-account-key.json
```

## Option C: Terraform Setup

See `terraform/gcp/service-account.tf` for Infrastructure as Code option.

```bash
cd terraform/gcp
terraform init
terraform apply
```

## Configure Environment Variables

Add to your `.env` file:

```bash
GCP_PROJECT_ID=your-gcp-project-id
GCP_KEY_PATH=./configs/gcp-service-account-key.json
```

## Verify Credentials

### Test with gcloud

```bash
# Activate service account
gcloud auth activate-service-account \
  --key-file=configs/gcp-service-account-key.json

# Verify identity
gcloud auth list

# Test monitoring access
gcloud monitoring metrics list --limit=5
```

### Test with Script

```bash
./scripts/test-gcp-connection.sh
```

## Monitored Services

The Stackdriver Exporter is configured to collect metrics from:

| Service | Metric Prefix | Examples |
|---------|--------------|----------|
| Cloud Run | `run.googleapis.com` | Request count, latency, instances |
| Pub/Sub | `pubsub.googleapis.com` | Message counts, ack latency |
| Cloud Functions | `cloudfunctions.googleapis.com` | Execution count, duration |
| Compute Engine | `compute.googleapis.com` | CPU, memory, disk |

### Adding More Services

Edit `docker-compose.yml` and update the `--monitoring.metrics-type-prefixes` flag:

```yaml
stackdriver-exporter:
  command:
    - '--monitoring.metrics-type-prefixes=compute.googleapis.com,run.googleapis.com,pubsub.googleapis.com,cloudfunctions.googleapis.com,storage.googleapis.com'
```

Available prefixes: https://cloud.google.com/monitoring/api/metrics_gcp

## Multi-Project Monitoring

To monitor multiple GCP projects:

### Option 1: Multiple Exporters

Add another exporter in `docker-compose.yml`:

```yaml
stackdriver-exporter-project2:
  image: prometheuscommunity/stackdriver-exporter:v0.15.0
  command:
    - '--google.project-id=second-project-id'
    # ... rest of config
  environment:
    GOOGLE_APPLICATION_CREDENTIALS: /etc/gcp/key-project2.json
  volumes:
    - ./configs/gcp-key-project2.json:/etc/gcp/key-project2.json:ro
```

### Option 2: Cross-Project IAM

Grant the service account access to multiple projects:

```bash
# For each additional project
gcloud projects add-iam-policy-binding OTHER_PROJECT_ID \
  --member="serviceAccount:monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/monitoring.viewer"
```

## Cloud Monitoring API Costs

### Pricing

- Monitoring API reads: **Free** (within quota)
- Quota: 6,000 requests per minute per project

### Quota Monitoring

Check your quota usage:

```bash
gcloud alpha monitoring quotas list \
  --project=$PROJECT_ID
```

## Troubleshooting

### "Permission Denied" Errors

1. Verify the service account has Monitoring Viewer role:

   ```bash
   gcloud projects get-iam-policy $PROJECT_ID \
     --flatten="bindings[].members" \
     --filter="bindings.members:monitoring-readonly"
   ```

2. Check Cloud Monitoring API is enabled:

   ```bash
   gcloud services list --enabled | grep monitoring
   ```

### "Invalid Credentials" Errors

1. Verify the key file exists and is valid JSON:

   ```bash
   cat configs/gcp-service-account-key.json | jq .
   ```

2. Check the key hasn't expired:

   ```bash
   gcloud iam service-accounts keys list \
     --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com
   ```

### No Metrics in Exporter

1. Check Stackdriver Exporter logs:

   ```bash
   docker-compose logs stackdriver-exporter
   ```

2. Verify metrics exist in GCP:

   ```bash
   gcloud monitoring metrics list \
     --filter="metric.type:run.googleapis.com" \
     --limit=10
   ```

3. Ensure you have running resources (Cloud Run services, etc.)

### Container Won't Start

1. Verify the key file path in `.env`
2. Check file permissions: `ls -la configs/gcp-service-account-key.json`
3. Ensure the file is mounted correctly in Docker

## Security Best Practices

### Key Rotation

Rotate service account keys every 90 days:

1. Create new key:

   ```bash
   gcloud iam service-accounts keys create configs/gcp-key-new.json \
     --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com
   ```

2. Update `GCP_KEY_PATH` in `.env`

3. Restart containers:

   ```bash
   docker-compose restart stackdriver-exporter
   ```

4. Verify metrics still flowing

5. Delete old key:

   ```bash
   gcloud iam service-accounts keys delete OLD_KEY_ID \
     --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com
   ```

### Audit Service Account Usage

Enable audit logging for the service account:

1. Go to: https://console.cloud.google.com/iam-admin/audit
2. Enable "Data Access" audit logs for Cloud Monitoring API

### Key File Security

- Never commit the key file to git
- Set restrictive permissions: `chmod 600 gcp-service-account-key.json`
- Consider using Google Secret Manager for production

## Service Account Key Contents

The JSON key file contains:

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",
  "client_email": "monitoring-readonly@project.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

⚠️ The `private_key` field is the sensitive part that must be protected.

## Next Steps

1. Run the setup script: `./scripts/setup.sh`
2. Upload dashboards: `./scripts/provision-dashboards.sh`
3. Verify GCP metrics appear in Grafana
