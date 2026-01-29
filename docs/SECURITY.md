# Security Guide

This document outlines security considerations and best practices for the multi-cloud monitoring stack.

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SECURITY BOUNDARIES                             │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         HOME NETWORK                                 │   │
│  │                                                                     │   │
│  │   ┌─────────────────────────────────────────────────────────────┐  │   │
│  │   │                    RASPBERRY PI                              │  │   │
│  │   │                                                             │  │   │
│  │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │  │   │
│  │   │  │   .env      │  │ GCP Key     │  │ Docker      │        │  │   │
│  │   │  │  (secrets)  │  │   File      │  │ Containers  │        │  │   │
│  │   │  │             │  │             │  │             │        │  │   │
│  │   │  │ 600 perms   │  │ 600 perms   │  │ Non-root    │        │  │   │
│  │   │  │ gitignored  │  │ gitignored  │  │ (mostly)    │        │  │   │
│  │   │  └─────────────┘  └─────────────┘  └─────────────┘        │  │   │
│  │   │                                                             │  │   │
│  │   │  Outbound HTTPS only (443)  ─────────────────────────────►│  │   │
│  │   │  No inbound ports exposed                                   │  │   │
│  │   └─────────────────────────────────────────────────────────────┘  │   │
│  │                                                                     │   │
│  │   NAT Router (no port forwarding required)                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  External Services (TLS encrypted):                                         │
│  • Grafana Cloud (metrics storage)                                         │
│  • AWS CloudWatch API (metric collection)                                  │
│  • GCP Cloud Monitoring API (metric collection)                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Credential Security

### Types of Credentials

| Credential | Purpose | Storage | Sensitivity |
|------------|---------|---------|-------------|
| Grafana Cloud API Key | Remote write metrics | `.env` | Medium |
| Grafana Cloud Token | Dashboard provisioning | `.env` | Medium |
| AWS Access Key | CloudWatch read | `.env` | High |
| AWS Secret Key | CloudWatch read | `.env` | Critical |
| GCP Service Account Key | Cloud Monitoring read | JSON file | Critical |

### Secure Storage

#### `.env` File

```bash
# Set restrictive permissions
chmod 600 .env

# Verify permissions
ls -la .env
# Should show: -rw------- 1 user user ... .env
```

#### GCP Service Account Key

```bash
# Set restrictive permissions
chmod 600 configs/gcp-service-account-key.json

# Verify only owner can read
ls -la configs/gcp-service-account-key.json
```

### Git Safety

The `.gitignore` is configured to exclude sensitive files:

```gitignore
# Environment files
.env
.env.local
*.env

# GCP keys
*-service-account*.json
gcp-*.json
*-key.json

# Terraform state
*.tfstate
*.tfstate.*
```

**Always verify before committing:**

```bash
# Check what would be committed
git status

# Verify no secrets in staged files
git diff --cached | grep -i "key\|secret\|password\|token"
```

## Least Privilege Access

### AWS IAM User

The IAM user has **read-only** permissions:

```json
{
  "Action": [
    "cloudwatch:GetMetricStatistics",
    "cloudwatch:GetMetricData",
    "cloudwatch:ListMetrics",
    "tag:GetResources",
    "lambda:ListFunctions",
    "lambda:ListTags",
    "sqs:ListQueues",
    "sqs:GetQueueAttributes",
    "ecs:ListClusters",
    "ecs:ListServices",
    "ecs:DescribeServices",
    "apigateway:GET"
  ]
}
```

**Cannot:**

- Modify or delete any resources
- Change IAM policies
- Access resource data (only metadata)
- Create or modify CloudWatch alarms

### GCP Service Account

The service account has only the **Monitoring Viewer** role:

```
roles/monitoring.viewer
```

**Cannot:**

- Modify metrics or dashboards
- Access other GCP services
- Modify IAM policies
- Access any data (only monitoring metrics)

### Grafana Cloud

**Remote Write Token:**

- `metrics:write` permission only
- Cannot read metrics or access dashboards

**Service Account Token:**

- `Editor` role for dashboard management
- Scoped to your specific Grafana instance

## Network Security

### Outbound-Only Architecture

The Raspberry Pi only makes outbound connections:

- No inbound ports need to be opened
- Works behind NAT without port forwarding
- Reduces attack surface significantly

### TLS Encryption

All external communications use TLS 1.2+:

- Grafana Cloud remote write: HTTPS
- AWS CloudWatch API: HTTPS
- GCP Cloud Monitoring API: HTTPS

### Internal Network

Docker containers communicate on an isolated bridge network:

```yaml
networks:
  monitoring:
    driver: bridge
    name: monitoring-network
```

**Exposed ports (localhost only):**
| Port | Service | Purpose |
|------|---------|---------|
| 8429 | vmagent | Self-monitoring |
| 5000 | YACE | AWS metrics |
| 9255 | Stackdriver | GCP metrics |
| 9100 | Node Exporter | System metrics |
| 8080/8081 | cAdvisor | Container metrics |

These ports are only accessible from the Raspberry Pi itself.

## Container Security

### Non-Root Execution

Most containers run as non-root users:

| Container | User | Notes |
|-----------|------|-------|
| vmagent | nobody | |
| yace | nobody | |
| stackdriver-exporter | nobody | |
| node-exporter | nobody | |
| cadvisor | root | Required for system access |

### cAdvisor Privileged Mode

cAdvisor requires privileged access to read container metrics:

```yaml
cadvisor:
  privileged: true
  volumes:
    - /:/rootfs:ro
    - /var/run:/var/run:ro
    - /sys:/sys:ro
    - /var/lib/docker/:/var/lib/docker:ro
```

**Mitigations:**

- Read-only mounts where possible
- Container isolation via Docker
- Official image from Google

### Image Security

Use pinned, verified images:

```yaml
# Good - pinned version from verified publisher
image: victoriametrics/vmagent:v1.103.0

# Bad - floating tag, could change
image: victoriametrics/vmagent:latest
```

**Regular updates:**

```bash
# Check for updates
docker-compose pull

# Apply updates
docker-compose up -d
```

## Credential Rotation

### AWS Access Keys

Rotate every 90 days:

```bash
# 1. Create new access key
aws iam create-access-key --user-name monitoring-readonly

# 2. Update .env with new credentials

# 3. Restart containers
docker-compose restart

# 4. Verify metrics still flowing

# 5. Delete old access key
aws iam delete-access-key \
  --user-name monitoring-readonly \
  --access-key-id OLDKEYID
```

### GCP Service Account Keys

Rotate every 90 days:

```bash
# 1. Create new key
gcloud iam service-accounts keys create configs/gcp-key-new.json \
  --iam-account=monitoring-readonly@PROJECT.iam.gserviceaccount.com

# 2. Update GCP_KEY_PATH in .env

# 3. Restart exporter
docker-compose restart stackdriver-exporter

# 4. Verify metrics flowing

# 5. Delete old key
gcloud iam service-accounts keys delete OLDKEYID \
  --iam-account=monitoring-readonly@PROJECT.iam.gserviceaccount.com

# 6. Remove old key file
rm configs/gcp-key-old.json
```

### Grafana Cloud API Keys

Rotate annually or if compromised:

1. Generate new key in Grafana Cloud UI
2. Update `.env`
3. Restart vmagent
4. Delete old key from Grafana Cloud

## Raspberry Pi Hardening

### SSH Security

```bash
# Use SSH keys instead of passwords
# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no

# Restart SSH
sudo systemctl restart sshd
```

### Firewall

```bash
# Install and configure UFW
sudo apt install ufw

# Default deny incoming
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (from specific IP if possible)
sudo ufw allow from 192.168.1.0/24 to any port 22

# Enable firewall
sudo ufw enable
```

### Automatic Updates

```bash
# Enable unattended security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Fail2ban

```bash
# Install fail2ban for SSH protection
sudo apt install fail2ban
sudo systemctl enable fail2ban
```

## Audit and Monitoring

### Monitor Credential Usage

**AWS CloudTrail:**

- Enable CloudTrail in your AWS account
- Monitor for unusual API calls from the monitoring user

**GCP Audit Logs:**

- Enable Data Access audit logs
- Monitor service account activity

### Local Logging

```bash
# View authentication logs
sudo journalctl -u ssh

# View Docker logs
docker-compose logs --since 24h
```

### Alerting on Security Events

Consider adding alerts for:

- SSH authentication failures
- Docker container restarts
- vmagent authentication errors
- Unusual metric patterns

## Incident Response

### If Credentials Are Compromised

1. **Immediately revoke compromised credentials:**

   ```bash
   # AWS
   aws iam delete-access-key --user-name monitoring-readonly --access-key-id COMPROMISED_KEY

   # GCP
   gcloud iam service-accounts keys delete KEY_ID --iam-account=...

   # Grafana Cloud
   # Delete from web UI immediately
   ```

2. **Rotate all credentials** (attacker may have accessed others)

3. **Review audit logs** for unauthorized access

4. **Update `.env`** with new credentials

5. **Restart containers** to use new credentials

### If Raspberry Pi Is Compromised

1. **Disconnect from network** immediately

2. **Revoke all cloud credentials** from another device

3. **Review cloud audit logs** for unauthorized access

4. **Reimage the Raspberry Pi** with fresh OS

5. **Rotate all credentials** before reconnecting

## Security Checklist

### Initial Setup

- [ ] `.env` file has 600 permissions
- [ ] GCP key file has 600 permissions
- [ ] `.gitignore` includes all secret files
- [ ] SSH password authentication disabled
- [ ] Firewall enabled and configured
- [ ] Automatic security updates enabled

### Ongoing

- [ ] Rotate AWS keys every 90 days
- [ ] Rotate GCP keys every 90 days
- [ ] Review Grafana Cloud API keys annually
- [ ] Update Docker images monthly
- [ ] Review audit logs quarterly
- [ ] Test backup restoration annually

## Additional Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [GCP Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Raspberry Pi Security](https://www.raspberrypi.org/documentation/configuration/security.md)
