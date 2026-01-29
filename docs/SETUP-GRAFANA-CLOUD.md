# Grafana Cloud Setup Guide

This guide walks you through setting up Grafana Cloud for the multi-cloud monitoring stack.

## Overview

Grafana Cloud provides:

- **Prometheus-compatible metrics storage** (10,000 series, 14-day retention on free tier)
- **Grafana dashboards** for visualization
- **Alerting** with notifications to Slack, email, etc.

## Create a Grafana Cloud Account

### 1. Sign Up

1. Go to https://grafana.com/products/cloud/
2. Click "Create free account"
3. Sign up with GitHub, Google, or email
4. Verify your email address

### 2. Create a Stack

1. After signing in, you'll be prompted to create a stack
2. Choose a stack name (e.g., "homelab-monitoring")
3. Select a region closest to your Raspberry Pi
4. Click "Create Stack"

## Get Remote Write Credentials

The Raspberry Pi will push metrics to Grafana Cloud using Remote Write.

### 1. Navigate to Stack Details

1. Go to https://grafana.com/orgs/YOUR_ORG/stacks
2. Click on your stack name
3. Click "Details" or the gear icon

### 2. Find Prometheus Configuration

1. In the stack details, find "Prometheus"
2. Click "Details" or expand the section

### 3. Get Remote Write URL

Look for "Remote Write Endpoint". It looks like:

```
https://prometheus-prod-XX-prod-us-central-0.grafana.net/api/prom/push
```

Save this URL for the `GRAFANA_CLOUD_PROMETHEUS_URL` in your `.env` file.

### 4. Get Username

The username is your numeric Grafana.com user ID, shown in the Prometheus details section. It's a number like `123456`.

Save this for `GRAFANA_CLOUD_USERNAME` in your `.env` file.

### 5. Create API Key for Remote Write

1. Click "Generate now" next to "Password / API Key" in the Prometheus section
   - Or go to: https://grafana.com/orgs/YOUR_ORG/api-keys
2. Click "Add API Key"
3. Name: `raspberry-pi-monitoring`
4. Role: `MetricsPublisher`
5. Click "Create API Key"
6. **Copy the key immediately** (it won't be shown again)

The key looks like: `glc_eyJrIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwIiwidCI6IjEyMzQ1NiJ9`

Save this for `GRAFANA_CLOUD_API_KEY` in your `.env` file.

## Get Dashboard Provisioning Credentials

To upload dashboards programmatically, you need a Service Account Token.

### 1. Navigate to Your Grafana Instance

1. From your stack page, click "Launch" to open Grafana
2. Or go directly to: `https://YOUR-STACK.grafana.net`

### 2. Create Service Account

1. Go to Administration → Service Accounts (or Configuration → Service Accounts in older versions)
2. Click "Add service account"
3. Name: `dashboard-provisioner`
4. Role: `Editor` (or `Admin` if you want to manage folders too)
5. Click "Create"

### 3. Create Service Account Token

1. Click on the newly created service account
2. Click "Add service account token"
3. Name: `provisioning-token`
4. Expiration: Set as desired (or no expiration)
5. Click "Generate token"
6. **Copy the token immediately**

The token looks like: `glsa_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

Save the following for your `.env` file:

- `GRAFANA_CLOUD_URL`: `https://YOUR-STACK.grafana.net`
- `GRAFANA_CLOUD_API_TOKEN`: The token you just created

## Verify Configuration

### Test Remote Write Credentials

You can test your credentials with curl:

```bash
# Load your .env file
source .env

# Send a test metric
curl -X POST "${GRAFANA_CLOUD_PROMETHEUS_URL}" \
  -u "${GRAFANA_CLOUD_USERNAME}:${GRAFANA_CLOUD_API_KEY}" \
  -H "Content-Type: application/x-protobuf" \
  -H "Content-Encoding: snappy" \
  -H "X-Prometheus-Remote-Write-Version: 0.1.0" \
  -d ""

# Should return empty response with HTTP 204 or similar success code
```

### Test Dashboard API Credentials

```bash
# Load your .env file
source .env

# List dashboards
curl -s "${GRAFANA_CLOUD_URL}/api/search?type=dash-db" \
  -H "Authorization: Bearer ${GRAFANA_CLOUD_API_TOKEN}" | jq .
```

## Configure Alerting (Optional)

### Set Up Slack Notifications

1. In Grafana, go to Alerting → Contact points
2. Click "New contact point"
3. Name: `Slack Critical`
4. Type: Slack
5. Webhook URL: Your Slack webhook URL (see below)
6. Click "Test" to verify
7. Click "Save contact point"

#### Create Slack Webhook

1. Go to https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
3. Name: "Grafana Alerts"
4. Workspace: Select your workspace
5. Click "Create App"
6. Go to "Incoming Webhooks"
7. Enable "Activate Incoming Webhooks"
8. Click "Add New Webhook to Workspace"
9. Select the channel for alerts
10. Copy the Webhook URL

### Create Notification Policies

1. Go to Alerting → Notification policies
2. Edit the default policy or create new ones:
   - Critical alerts → Slack Critical channel
   - Warning alerts → Slack Warnings channel

## Free Tier Limits

The Grafana Cloud free tier includes:

| Resource | Limit |
|----------|-------|
| Active metric series | 10,000 |
| Metrics retention | 14 days |
| Grafana users | 3 |
| Alerting | Included |
| Dashboards | Unlimited |

### Monitoring Your Usage

1. Go to your stack details page
2. View "Usage" section
3. Check current series count

### Staying Within Limits

The monitoring stack is configured to stay under 10,000 series by:

- Using appropriate scrape intervals (5 min for CloudWatch)
- Dropping high-cardinality metrics via relabeling
- Tag-based discovery (only monitoring tagged resources)

If approaching limits:

1. Review metric relabel configs in `prometheus.yml`
2. Add more aggressive dropping rules
3. Consider recording rules for aggregation
4. Reduce number of monitored resources

## Summary of Credentials

After completing this guide, you should have:

| Variable | Example Value |
|----------|---------------|
| `GRAFANA_CLOUD_PROMETHEUS_URL` | `https://prometheus-prod-01-prod-us-central-0.grafana.net/api/prom/push` |
| `GRAFANA_CLOUD_USERNAME` | `123456` |
| `GRAFANA_CLOUD_API_KEY` | `glc_eyJrIjoiYWJjZGVm...` |
| `GRAFANA_CLOUD_URL` | `https://your-stack.grafana.net` |
| `GRAFANA_CLOUD_API_TOKEN` | `glsa_xxxxxxxxxxxx...` |

## Next Steps

1. [Set up AWS connector](SETUP-AWS-CONNECTOR.md)
2. [Set up GCP connector](SETUP-GCP-CONNECTOR.md)
3. Run the setup script: `./scripts/setup.sh`
4. Upload dashboards: `./scripts/provision-dashboards.sh`
