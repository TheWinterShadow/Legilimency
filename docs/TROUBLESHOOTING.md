# Troubleshooting Guide

This guide covers common issues and their solutions.

## Quick Diagnostics

### Check Overall Health

```bash
# Run health check script
./scripts/monitor-health.sh

# View all container statuses
docker-compose ps

# Check resource usage
docker stats --no-stream
```

### View Logs

```bash
# All containers
docker-compose logs -f

# Specific container
docker-compose logs -f vmagent
docker-compose logs -f yace
docker-compose logs -f stackdriver-exporter
```

## No Metrics in Grafana Cloud

### Symptom

Dashboards show "No Data" or metrics don't appear in Explore.

### Diagnosis Steps

#### 1. Check vmagent Remote Write

```bash
# Check vmagent logs for remote write status
docker-compose logs vmagent | grep -i "remote"

# Look for successful writes
docker-compose logs vmagent | grep -i "successfully"
```

**Expected output:**

```
vmagent | 2024-01-15T10:30:00.000Z | INFO | remotewrite.sendBlock | successfully pushed
```

#### 2. Verify Credentials

```bash
# Test remote write endpoint
source .env
curl -v -X POST "${GRAFANA_CLOUD_PROMETHEUS_URL}" \
  -u "${GRAFANA_CLOUD_USERNAME}:${GRAFANA_CLOUD_API_KEY}" \
  -H "Content-Type: application/x-protobuf" \
  -d ""
```

**Expected:** HTTP 204 or 200

**If 401/403:**

- Check `GRAFANA_CLOUD_USERNAME` (should be numeric)
- Verify `GRAFANA_CLOUD_API_KEY` has `metrics:write` permission
- Regenerate API key if needed

#### 3. Check vmagent Scraping

```bash
# Check if vmagent can reach exporters
curl http://localhost:8429/targets

# Check vmagent's internal metrics
curl http://localhost:8429/metrics | grep scrape_samples
```

#### 4. Verify Network Connectivity

```bash
# Test connectivity to Grafana Cloud
curl -I https://grafana.com

# Test DNS resolution
nslookup prometheus-prod-01-prod-us-central-0.grafana.net
```

### Solutions

| Issue | Solution |
|-------|----------|
| Invalid credentials | Regenerate API key in Grafana Cloud |
| Network blocked | Check firewall, ensure port 443 outbound allowed |
| Wrong URL format | URL should end with `/api/prom/push` |
| vmagent not running | `docker-compose up -d vmagent` |

## AWS Metrics Not Appearing

### Symptom

No `aws_*` metrics in Grafana, Lambda/SQS dashboards empty.

### Diagnosis Steps

#### 1. Check YACE Container

```bash
# View YACE logs
docker-compose logs yace

# Check YACE is healthy
docker-compose ps yace
```

**Look for:**

- "error" messages
- "invalid credentials"
- "access denied"

#### 2. Test AWS Credentials

```bash
source .env
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_REGION

# Test credentials
aws sts get-caller-identity

# List CloudWatch metrics
aws cloudwatch list-metrics --namespace AWS/Lambda
```

#### 3. Check YACE Metrics Endpoint

```bash
# Get metrics from YACE
curl http://localhost:5000/metrics | grep aws_

# Count AWS metrics
curl -s http://localhost:5000/metrics | grep -c "aws_"
```

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Invalid credentials | `InvalidClientTokenId` in logs | Check AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY |
| Missing permissions | `AccessDenied` in logs | Verify IAM policy is attached |
| No resources | 0 metrics returned | Ensure Lambda/SQS exist in monitored regions |
| Wrong region | No metrics | Check AWS_REGIONS_TO_MONITOR |
| Resources not tagged | Missing in discovery | Add required tags to resources |

### IAM Permission Verification

```bash
# List attached policies
aws iam list-attached-user-policies --user-name monitoring-readonly

# Get policy details
aws iam get-policy --policy-arn <policy-arn>
aws iam get-policy-version --policy-arn <policy-arn> --version-id v1
```

## GCP Metrics Not Appearing

### Symptom

No `stackdriver_*` metrics, Cloud Run dashboard empty.

### Diagnosis Steps

#### 1. Check Stackdriver Exporter

```bash
# View exporter logs
docker-compose logs stackdriver-exporter

# Check health
docker-compose ps stackdriver-exporter
```

#### 2. Verify Service Account Key

```bash
# Check key file exists
ls -la configs/gcp-service-account-key.json

# Validate JSON format
cat configs/gcp-service-account-key.json | jq .

# Check key hasn't expired
gcloud iam service-accounts keys list \
  --iam-account=monitoring-readonly@${GCP_PROJECT_ID}.iam.gserviceaccount.com
```

#### 3. Test with gcloud

```bash
# Activate service account
gcloud auth activate-service-account \
  --key-file=configs/gcp-service-account-key.json

# List metrics
gcloud monitoring metrics list --limit=5
```

#### 4. Check Exporter Metrics

```bash
curl http://localhost:9255/metrics | grep stackdriver
```

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Invalid key | `invalid_grant` | Regenerate service account key |
| Missing role | `permission denied` | Add Monitoring Viewer role |
| API not enabled | `API not enabled` | Enable Cloud Monitoring API |
| No resources | 0 metrics | Ensure Cloud Run/Pub/Sub resources exist |
| Wrong project | No matching metrics | Check GCP_PROJECT_ID |

## Container Issues

### Container Won't Start

```bash
# Check detailed status
docker-compose ps -a

# View startup logs
docker-compose logs --tail=50 <service-name>

# Check for resource constraints
docker system df
free -h
```

### Common Container Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Image pull failed | `manifest not found` | Check image name/tag, try `docker-compose pull` |
| Port conflict | `port already in use` | Check for conflicting services |
| Volume mount failed | `no such file or directory` | Verify file paths exist |
| Out of memory | Container killed | Reduce memory limits or add swap |
| ARM architecture | `exec format error` | Use ARM64-compatible images |

### Resource Issues on Raspberry Pi

```bash
# Check memory usage
free -h

# Check disk space
df -h

# Check CPU temperature
vcgencmd measure_temp

# Monitor in real-time
htop
```

**If memory constrained:**

```bash
# Reduce vmagent memory limit
# Edit docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 384M  # Reduce from 512M
```

## Network Connectivity

### Test Outbound Connectivity

```bash
# Test HTTPS
curl -I https://grafana.com

# Test DNS
nslookup grafana.com
dig grafana.com

# Test specific ports
nc -zv prometheus-prod-01-prod-us-central-0.grafana.net 443
```

### Firewall Issues

```bash
# Check UFW status
sudo ufw status

# Allow outbound HTTPS (should be default)
sudo ufw default allow outgoing
```

### Docker Network Issues

```bash
# List networks
docker network ls

# Inspect monitoring network
docker network inspect monitoring-network

# Check container networking
docker-compose exec vmagent ping yace
```

## Dashboard Issues

### Dashboards Show "No Data"

1. **Check datasource:**
   - Go to Grafana → Configuration → Data sources
   - Verify Prometheus datasource is configured
   - Test the datasource connection

2. **Check time range:**
   - Metrics may not exist for selected time period
   - Try "Last 1 hour" or "Last 6 hours"

3. **Check query:**
   - Open panel edit mode
   - Run query manually in Explore
   - Check for typos in metric names

### Template Variables Not Populating

```promql
# Verify metrics exist for variable query
label_values(aws_lambda_invocations_sum, function_name)
```

If no results:

- Metrics haven't arrived yet (wait 5-10 minutes)
- Metric name is different (check in Explore)
- No resources generating metrics

### Dashboard Import Errors

```bash
# Validate JSON
cat dashboards/aws-lambda.json | jq .

# Check for syntax errors
python3 -m json.tool dashboards/aws-lambda.json

# Re-run provisioning
./scripts/provision-dashboards.sh
```

## Performance Issues

### High CPU Usage

```bash
# Identify which container
docker stats --no-stream

# Check for scrape errors (causes retries)
docker-compose logs vmagent | grep -i error
```

**Solutions:**

- Increase scrape intervals
- Reduce number of metrics collected
- Drop high-cardinality metrics

### High Memory Usage

```bash
# Check memory per container
docker stats --format "table {{.Name}}\t{{.MemUsage}}"
```

**If vmagent using too much memory:**

- Reduce `-remoteWrite.queues` value
- Reduce `-remoteWrite.maxBlockSize`
- Add more aggressive metric dropping

### Disk Space Issues

```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df

# Clean up old images
docker system prune -a
```

## Log Analysis

### Search for Errors

```bash
# All containers
docker-compose logs 2>&1 | grep -i error

# With timestamps
docker-compose logs -t 2>&1 | grep -i error | tail -20
```

### Common Log Messages

| Message | Meaning | Action |
|---------|---------|--------|
| `successfully pushed` | Remote write working | None needed |
| `connection refused` | Target not reachable | Check container health |
| `context deadline exceeded` | Scrape timeout | Increase timeout |
| `sample limit exceeded` | Too many metrics | Add drop rules |
| `401 Unauthorized` | Invalid credentials | Check API keys |

## Recovery Procedures

### Full Stack Restart

```bash
docker-compose down
docker-compose up -d
sleep 30
docker-compose ps
```

### Clear vmagent Buffer

```bash
# If buffer corrupted
docker-compose down vmagent
docker volume rm raspberry-pi-monitoring_vmagent-data
docker-compose up -d vmagent
```

### Reset Everything

```bash
# Nuclear option - removes all data
docker-compose down -v
docker-compose up -d
```

## Getting Help

### Collect Diagnostics

```bash
# Create diagnostic bundle
{
  echo "=== Docker Compose Status ==="
  docker-compose ps

  echo -e "\n=== Container Logs (last 50 lines each) ==="
  for svc in vmagent yace stackdriver-exporter node-exporter cadvisor; do
    echo -e "\n--- $svc ---"
    docker-compose logs --tail=50 $svc 2>&1
  done

  echo -e "\n=== System Resources ==="
  free -h
  df -h

  echo -e "\n=== Network Test ==="
  curl -sI https://grafana.com | head -5
} > diagnostics.txt 2>&1

echo "Diagnostics saved to diagnostics.txt"
```

### Information to Include When Asking for Help

1. Output of `docker-compose ps`
2. Relevant container logs
3. Contents of `.env` (with secrets redacted)
4. Error messages
5. What you've already tried
