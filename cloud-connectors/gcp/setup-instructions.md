# GCP Cloud Connector Setup Instructions

This guide walks you through creating a GCP service account with Monitoring Viewer role for collecting Cloud Monitoring metrics.

## Prerequisites

- GCP project with billing enabled (required for Cloud Monitoring API)
- gcloud CLI installed: https://cloud.google.com/sdk/docs/install
- Project Owner or Editor role (to create service accounts)

## Step 1: Install and Authenticate gcloud CLI

```bash
# Install gcloud CLI (if not installed)
# macOS: brew install google-cloud-sdk
# Linux: Follow instructions at https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

## Step 2: Enable Cloud Monitoring API

The Cloud Monitoring API must be enabled for the exporter to work.

```bash
# Enable Cloud Monitoring API
gcloud services enable monitoring.googleapis.com

# Verify it's enabled
gcloud services list --enabled | grep monitoring
```

Expected output:

```
monitoring.googleapis.com    Cloud Monitoring API
```

## Step 3: Create Service Account

Create a service account specifically for monitoring (read-only access).

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"

# Create service account
gcloud iam service-accounts create monitoring-readonly \
  --display-name="Monitoring Read-Only" \
  --description="Service account for external monitoring system" \
  --project=$PROJECT_ID
```

Expected output:

```
Created service account [monitoring-readonly].
```

## Step 4: Grant Monitoring Viewer Role

Grant the service account read-only access to Cloud Monitoring metrics.

```bash
# Grant Monitoring Viewer role (read-only)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/monitoring.viewer"
```

Expected output:

```
Updated IAM policy for project [your-gcp-project-id].
bindings:
- members:
  - serviceAccount:monitoring-readonly@your-gcp-project-id.iam.gserviceaccount.com
  role: roles/monitoring.viewer
```

## Step 5: Create and Download JSON Key

Generate a JSON key file that the Stackdriver Exporter will use for authentication.

```bash
# Create key file in configs directory
gcloud iam service-accounts keys create ./configs/gcp-service-account-key.json \
  --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com
```

**Security Warning**: This JSON file contains sensitive credentials. It's automatically added to `.gitignore`.

Expected output:

```
created key [abc123def456...] of type [json] as [./configs/gcp-service-account-key.json] for [monitoring-readonly@your-project-id.iam.gserviceaccount.com]
```

## Step 6: Verify Service Account

Verify the service account was created correctly:

```bash
# Describe service account
gcloud iam service-accounts describe \
  monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com

# List service account keys (should show the new key)
gcloud iam service-accounts keys list \
  --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com
```

## Step 7: Verify Key File

Check that the key file was created:

```bash
# Verify file exists
ls -la ./configs/gcp-service-account-key.json

# Verify JSON structure (should show service account email)
cat ./configs/gcp-service-account-key.json | jq -r '.client_email'
```

Expected output:

```
monitoring-readonly@your-project-id.iam.gserviceaccount.com
```

## Step 8: Test Credentials

### Using gcloud CLI

```bash
# Set application default credentials to use the service account key
export GOOGLE_APPLICATION_CREDENTIALS="./configs/gcp-service-account-key.json"

# Test Monitoring API access
gcloud monitoring metrics list --limit=5
```

### Using Test Script

```bash
# From the project root directory
./scripts/test-gcp-connection.sh
```

Expected output:

```
✓ GCP credentials configured
✓ GCP project verified: your-gcp-project-id
✓ Cloud Monitoring API accessible
✓ Service account: monitoring-readonly@your-project-id.iam.gserviceaccount.com
```

## Step 9: Add to .env File

1. Open `.env` file (create from `.env.example` if needed)
2. Add GCP configuration:

```bash
GCP_PROJECT_ID=your-gcp-project-id
GCP_KEY_PATH=./configs/gcp-service-account-key.json
```

3. Save the file
4. **Verify `configs/gcp-service-account-key.json` is in `.gitignore`**

## Step 10: Test Stackdriver Exporter

After starting the Docker stack:

```bash
# Check Stackdriver Exporter logs
docker-compose logs stackdriver-exporter

# Check metrics endpoint
curl http://localhost:9255/metrics | grep stackdriver
```

You should see GCP metrics if you have Cloud Run services, Compute Engine instances, or Pub/Sub topics in your project.

## Troubleshooting

### "Permission Denied" Errors

- Verify the service account has `roles/monitoring.viewer` role
- Check that Cloud Monitoring API is enabled
- Ensure the JSON key file path is correct in `.env`

### No Metrics Appearing

- Verify GCP project ID is correct
- Check that resources exist in the project (Cloud Run, Compute Engine, etc.)
- Review Stackdriver Exporter logs: `docker-compose logs stackdriver-exporter`
- Verify metric type prefixes in `docker-compose.yml` match your resources

### API Quota Exceeded

- Cloud Monitoring API has quotas (check in GCP Console)
- Reduce scrape interval if hitting limits
- Expected usage: Well within free tier for typical homelab

### Key File Not Found

- Verify the path in `.env` matches the actual file location
- Use absolute path if relative path doesn't work: `/full/path/to/configs/gcp-service-account-key.json`
- Check file permissions: `chmod 600 ./configs/gcp-service-account-key.json`

## Security Best Practices

1. **Least Privilege**: Service account has only `roles/monitoring.viewer` (read-only)
2. **Key Rotation**: Rotate service account keys every 90 days
3. **Key Management**: Delete unused keys from GCP Console
4. **Secure Storage**: Keep JSON key file secure, never commit to git
5. **Access Logging**: Monitor service account usage in Cloud Audit Logs

## Rotating Service Account Keys

```bash
# List existing keys
gcloud iam service-accounts keys list \
  --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com

# Create new key
gcloud iam service-accounts keys create ./configs/gcp-service-account-key-new.json \
  --iam-account=monitoring-readonly@${PROJECT_ID}.iam.gserviceaccount.com

# Update .env to point to new key
# Test the new key
# Delete old key from GCP Console: IAM → Service Accounts → monitoring-readonly → Keys
```

## Alternative: Using Terraform

If you prefer Infrastructure as Code, see `terraform/gcp/service-account.tf` for Terraform configuration.

```bash
cd terraform/gcp
terraform init
terraform plan
terraform apply
```

The Terraform output will include the service account email and key path.

## Next Steps

- [ ] Test AWS connector setup: `docs/SETUP-AWS-CONNECTOR.md`
- [ ] Configure Grafana Cloud: `docs/SETUP-GRAFANA-CLOUD.md`
- [ ] Start monitoring stack: `./scripts/setup.sh`
