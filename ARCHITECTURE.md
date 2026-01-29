# Architecture Documentation

## System Overview

This monitoring system collects metrics from AWS and GCP cloud services using a Raspberry Pi as the collection point, with Grafana Cloud handling storage, visualization, and alerting. This architecture minimizes cloud costs while providing enterprise-grade monitoring capabilities.

## Design Principles

1. **Cost Efficiency**: Use free tiers and minimize cloud resource usage
2. **Resilience**: Local buffering handles network outages gracefully
3. **Least Privilege**: All credentials are read-only
4. **Simplicity**: Docker Compose for easy deployment and maintenance
5. **Observability**: Monitor the monitoring system itself

## Component Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              RASPBERRY PI                                     │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                          Docker Network: monitoring                      ││
│  │                                                                         ││
│  │   ┌───────────────┐     ┌───────────────┐     ┌───────────────┐       ││
│  │   │   YACE        │     │  Stackdriver  │     │ Node Exporter │       ││
│  │   │   (AWS)       │     │  Exporter     │     │ (System)      │       ││
│  │   │   :5000       │     │  (GCP)        │     │ :9100         │       ││
│  │   │               │     │  :9255        │     │               │       ││
│  │   └───────┬───────┘     └───────┬───────┘     └───────┬───────┘       ││
│  │           │                     │                     │               ││
│  │           │   ┌───────────────┐ │                     │               ││
│  │           │   │   cAdvisor    │ │                     │               ││
│  │           │   │  (Containers) │ │                     │               ││
│  │           │   │  :8081        │ │                     │               ││
│  │           │   └───────┬───────┘ │                     │               ││
│  │           │           │         │                     │               ││
│  │           ▼           ▼         ▼                     ▼               ││
│  │   ┌─────────────────────────────────────────────────────────────────┐││
│  │   │                         vmagent                                  │││
│  │   │                                                                  │││
│  │   │  • Scrapes all exporters (Prometheus protocol)                  │││
│  │   │  • Aggregates and relabels metrics                              │││
│  │   │  • Buffers to disk during network issues                        │││
│  │   │  • Remote writes to Grafana Cloud                               │││
│  │   │                                                                  │││
│  │   │  Port: :8429 (self-monitoring)                                  │││
│  │   └─────────────────────────────────────────────────────────────────┘││
│  │                                    │                                 ││
│  └────────────────────────────────────┼─────────────────────────────────┘│
│                                       │                                   │
│                                       │ HTTPS (Port 443)                  │
│                                       │ Remote Write Protocol             │
└───────────────────────────────────────┼───────────────────────────────────┘
                                        │
                                        ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                              GRAFANA CLOUD                                     │
│                                                                               │
│   ┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────┐ │
│   │  Prometheus         │    │  Grafana             │    │  Alerting       │ │
│   │  (Metrics Store)    │◄───│  (Visualization)     │────│  (Notifications)│ │
│   │                     │    │                      │    │                 │ │
│   │  • Remote Write     │    │  • Dashboards        │    │  • Alert Rules  │ │
│   │  • PromQL Query     │    │  • Explore           │    │  • Slack        │ │
│   │  • 14-day retention │    │  • Variables         │    │  • Email        │ │
│   │  • 10k series limit │    │  • Annotations       │    │  • PagerDuty    │ │
│   └─────────────────────┘    └──────────────────────┘    └─────────────────┘ │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Metric Collection

```
AWS CloudWatch API                   GCP Cloud Monitoring API
      │                                      │
      │ GetMetricData                        │ ListTimeSeries
      │ (every 5 minutes)                    │ (every 1 minute)
      ▼                                      ▼
┌──────────────┐                    ┌───────────────────┐
│     YACE     │                    │ Stackdriver       │
│              │                    │ Exporter          │
│ Converts AWS │                    │                   │
│ metrics to   │                    │ Converts GCP      │
│ Prometheus   │                    │ metrics to        │
│ format       │                    │ Prometheus format │
└──────┬───────┘                    └─────────┬─────────┘
       │                                      │
       │ /metrics                             │ /metrics
       │ (Prometheus exposition format)       │ (Prometheus exposition format)
       ▼                                      ▼
┌─────────────────────────────────────────────────────────┐
│                        vmagent                          │
│                                                         │
│  1. Scrapes /metrics endpoints from all exporters      │
│  2. Applies metric_relabel_configs (filtering, labels) │
│  3. Buffers to local disk (configurable size)          │
│  4. Sends to Grafana Cloud via Remote Write            │
└─────────────────────────────────────────────────────────┘
```

### 2. Scrape Intervals

| Exporter | Interval | Rationale |
|----------|----------|-----------|
| vmagent (self) | 30s | Quick feedback on scraper health |
| YACE (AWS) | 300s | CloudWatch standard metrics are 5-minute resolution |
| Stackdriver (GCP) | 60s | GCP metrics have 1-minute resolution |
| Node Exporter | 60s | Balance between freshness and resource usage |
| cAdvisor | 60s | Container metrics don't change rapidly |

### 3. Remote Write Pipeline

```
vmagent                                        Grafana Cloud
   │                                                │
   │  1. Collect scraped metrics                   │
   │  2. Apply external_labels                     │
   │  3. Batch metrics (by time window)            │
   │  4. Compress with snappy                      │
   │  5. Send via HTTPS POST                       │
   │──────────────────────────────────────────────►│
   │                                               │
   │  Response: 200 OK / 4xx / 5xx                 │
   │◄──────────────────────────────────────────────│
   │                                               │
   │  On failure:                                  │
   │  6. Queue to disk buffer                      │
   │  7. Retry with exponential backoff            │
   │  8. Resume when connection restored           │
```

## Component Details

### vmagent (VictoriaMetrics Agent)

**Purpose**: Central scraping agent and remote write proxy

**Why vmagent?**

- Lightweight (uses less memory than Prometheus)
- Built-in disk buffering for network resilience
- Native remote write support
- Efficient metric relabeling

**Key Configuration**:

```yaml
command:
  - '--promscrape.config=/etc/prometheus/prometheus.yml'
  - '--remoteWrite.url=${GRAFANA_CLOUD_PROMETHEUS_URL}'
  - '--remoteWrite.tmpDataPath=/vmagent-data'
  - '--remoteWrite.maxDiskUsagePerURL=1GB'
```

### YACE (Yet Another CloudWatch Exporter)

**Purpose**: Convert AWS CloudWatch metrics to Prometheus format

**How it works**:

1. Discovers AWS resources via tags and API calls
2. Calls CloudWatch GetMetricData API
3. Exposes metrics in Prometheus format on :5000/metrics

**Supported Services**:

- AWS Lambda (invocations, errors, duration, concurrency)
- AWS SQS (queue depth, message age, throughput)
- AWS ECS (CPU, memory utilization)
- AWS API Gateway (request count, errors, latency)

### Stackdriver Exporter

**Purpose**: Convert GCP Cloud Monitoring metrics to Prometheus format

**How it works**:

1. Calls GCP Cloud Monitoring API (ListTimeSeries)
2. Converts metric types to Prometheus format
3. Exposes on :9255/metrics

**Supported Services**:

- GCP Cloud Run (request count, latency, instances)
- GCP Pub/Sub (message counts, acknowledgments)
- GCP Cloud Functions (executions, errors)

### Node Exporter

**Purpose**: Collect Raspberry Pi system metrics

**Metrics collected**:

- CPU usage and load average
- Memory utilization
- Disk I/O and space
- Network statistics
- System uptime

### cAdvisor

**Purpose**: Collect Docker container metrics

**Metrics collected**:

- Container CPU usage
- Container memory usage
- Container network I/O
- Container filesystem usage

## Network Architecture

```
Internet
    │
    │ Outbound HTTPS (443)
    │
┌───┴───────────────────────────────────────────┐
│             Home Router (NAT)                  │
│                                               │
│  No inbound ports required                    │
│  All traffic is outbound                      │
└───┬───────────────────────────────────────────┘
    │
    │ Local Network
    │
┌───┴───────────────────────────────────────────┐
│             Raspberry Pi                       │
│                                               │
│  Internal Docker network: monitoring          │
│  Exposed ports (localhost only):              │
│    - 8429 (vmagent metrics)                   │
│    - 5000 (YACE metrics)                      │
│    - 9255 (Stackdriver metrics)               │
│    - 9100 (Node Exporter metrics)             │
│    - 8080 (cAdvisor web UI)                   │
│    - 8081 (cAdvisor metrics)                  │
└───────────────────────────────────────────────┘
```

## Security Model

### Credential Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Credential Storage                            │
│                                                                 │
│  .env file (never committed to git)                            │
│    ├── GRAFANA_CLOUD_* credentials                             │
│    ├── AWS_ACCESS_KEY_ID / SECRET_ACCESS_KEY                   │
│    └── GCP_KEY_PATH (points to service account JSON)           │
│                                                                 │
│  configs/gcp-service-account-key.json (never committed)        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ docker-compose.yml
                              │ environment variables
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Container Runtime                             │
│                                                                 │
│  vmagent:                                                       │
│    GRAFANA_CLOUD_USERNAME                                       │
│    GRAFANA_CLOUD_API_KEY                                        │
│                                                                 │
│  yace:                                                          │
│    AWS_ACCESS_KEY_ID                                            │
│    AWS_SECRET_ACCESS_KEY                                        │
│    AWS_REGION                                                   │
│                                                                 │
│  stackdriver-exporter:                                          │
│    GOOGLE_APPLICATION_CREDENTIALS (mounted volume)              │
└─────────────────────────────────────────────────────────────────┘
```

### Permission Model

| Component | Required Permissions |
|-----------|---------------------|
| AWS IAM User | cloudwatch:GetMetricData, cloudwatch:ListMetrics, tag:GetResources, lambda:ListFunctions, sqs:ListQueues, ecs:ListClusters, apigateway:GET |
| GCP Service Account | roles/monitoring.viewer |
| Grafana Cloud | metrics:write (remote write), dashboards:* (provisioning) |

## Failure Modes and Recovery

### Network Outage

```
1. vmagent detects failed remote write
2. Metrics buffered to disk (up to 1GB)
3. Exponential backoff on retries
4. When connection restored:
   - Buffered metrics sent in order
   - No data loss if within buffer capacity
```

### Exporter Failure

```
1. vmagent scrape fails (timeout)
2. up{job="..."} metric goes to 0
3. Alert triggered (optional)
4. vmagent continues scraping other exporters
5. Failed exporter auto-recovers on container restart
```

### Raspberry Pi Reboot

```
1. Docker containers stopped
2. On boot: containers auto-start (restart: unless-stopped)
3. vmagent disk buffer preserved (named volume)
4. Metrics resume flowing within 60 seconds
```

## Scaling Considerations

### Current Limits (Grafana Cloud Free Tier)

| Resource | Limit | Typical Usage |
|----------|-------|---------------|
| Active series | 10,000 | ~2,000-5,000 |
| Retention | 14 days | N/A |
| Ingestion rate | 10k samples/sec | ~100-500 samples/sec |

### Staying Within Limits

1. **Metric relabeling**: Drop unnecessary metrics
2. **Scrape intervals**: Use appropriate intervals per service
3. **Tag-based discovery**: Only monitor tagged resources
4. **Aggregation**: Use recording rules if approaching limits

### Future Expansion

```
Multi-Pi Setup:
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Pi #1        │    │ Pi #2        │    │ Pi #3        │
│ Location: LA │    │ Location: NYC│    │ Location: EU │
│              │    │              │    │              │
│ external_    │    │ external_    │    │ external_    │
│ labels:      │    │ labels:      │    │ labels:      │
│   cluster:   │    │   cluster:   │    │   cluster:   │
│   homelab-la │    │   homelab-nyc│    │   homelab-eu │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                           ▼
               ┌──────────────────────┐
               │   Grafana Cloud      │
               │                      │
               │   Query by cluster:  │
               │   {cluster="..."}    │
               └──────────────────────┘
```

## Monitoring the Monitor

### Self-Monitoring Metrics

vmagent exposes metrics about its own operation:

```promql
# Successful remote writes
rate(vmagent_remotewrite_requests_total{status="2xx"}[5m])

# Failed remote writes
rate(vmagent_remotewrite_requests_total{status=~"4xx|5xx"}[5m])

# Pending samples in buffer
vmagent_remotewrite_pending_data_bytes

# Scrape success rate
up{job=~".*"}
```

### Health Checks

Each container has a health check:

```yaml
healthcheck:
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:PORT/metrics"]
  interval: 30s
  timeout: 10s
  retries: 3
```

## References

- [VictoriaMetrics vmagent](https://docs.victoriametrics.com/vmagent.html)
- [YACE Documentation](https://github.com/nerdswords/yet-another-cloudwatch-exporter)
- [Stackdriver Exporter](https://github.com/prometheus-community/stackdriver_exporter)
- [Grafana Cloud Remote Write](https://grafana.com/docs/grafana-cloud/data-configuration/metrics/metrics-prometheus/)
- [Prometheus Remote Write Specification](https://prometheus.io/docs/concepts/remote_write_spec/)
