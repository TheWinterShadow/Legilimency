# Multi-Cloud Monitoring with Raspberry Pi & Grafana Cloud

A production-ready monitoring solution that collects metrics from AWS and GCP infrastructure using a Raspberry Pi, with visualization and alerting through Grafana Cloud.

## Features

- **Multi-cloud monitoring**: AWS (Lambda, SQS, ECS, API Gateway) and GCP (Cloud Run, Pub/Sub)
- **Zero cloud VM costs**: Runs entirely on a Raspberry Pi at home
- **Production-ready dashboards**: Pre-built Grafana dashboards for all services
- **Slack alerting**: Configurable alerts for critical issues
- **14-day metric retention**: Grafana Cloud free tier included
- **Network resilience**: Local buffering during outages with automatic catch-up

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Raspberry Pi at Home                        │
│                 (Always Running, ~$1.50/mo electricity)     │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Docker Stack:                                        │  │
│  │  • vmagent (metric collector & remote writer)        │  │
│  │  • YACE (AWS CloudWatch → Prometheus metrics)        │  │
│  │  • Stackdriver Exporter (GCP → Prometheus metrics)   │  │
│  │  • Node Exporter (system metrics)                    │  │
│  │  • cAdvisor (container metrics)                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                  │
│                          │ Remote Write (HTTPS)             │
│                          │ Every 15-60 seconds              │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Grafana Cloud (Free Tier)                      │
│                                                             │
│  ┌──────────────────┐         ┌─────────────────────────┐  │
│  │  Prometheus      │◀────────│  Grafana Dashboards     │  │
│  │  (Metrics Store) │  Query  │  (Visualization)        │  │
│  │                  │         │                         │  │
│  │  • 10k series    │         │  • Pre-built dashboards │  │
│  │  • 14-day retain │         │  • Custom views         │  │
│  │  • Free tier     │         │  • Alerts (Slack)       │  │
│  └──────────────────┘         └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Raspberry Pi 4 (4GB+ RAM recommended) with Ubuntu Server 22.04 LTS
- Docker and Docker Compose installed
- Grafana Cloud account (free tier: https://grafana.com/products/cloud/)
- AWS account with read-only IAM user
- GCP account with Monitoring Viewer service account

### 5-Minute Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/raspberry-pi-monitoring.git
   cd raspberry-pi-monitoring
   ```

2. **Configure credentials**

   ```bash
   cp .env.example .env
   nano .env  # Fill in your credentials
   ```

3. **Set up cloud credentials**

   ```bash
   # For AWS: Follow cloud-connectors/aws/setup-instructions.md
   # For GCP: Follow cloud-connectors/gcp/setup-instructions.md
   ```

4. **Run the setup script**

   ```bash
   chmod +x scripts/*.sh
   ./scripts/setup.sh
   ```

5. **Upload dashboards to Grafana Cloud**

   ```bash
   ./scripts/provision-dashboards.sh
   ```

6. **Open Grafana Cloud and view your metrics!**

## Project Structure

```
raspberry-pi-monitoring/
├── docker-compose.yml          # Main orchestration
├── .env.example                # Template for secrets
├── configs/
│   ├── prometheus.yml          # vmagent scrape config
│   ├── yace-config.yml         # AWS CloudWatch scraping
│   ├── alerts/                 # Alert rule definitions
│   └── grafana-cloud/          # Grafana Cloud configs
├── dashboards/                 # Grafana dashboard JSONs
├── scripts/                    # Setup and maintenance scripts
├── cloud-connectors/           # Cloud provider setup guides
│   ├── aws/                    # AWS IAM policy and instructions
│   └── gcp/                    # GCP service account setup
├── docs/                       # Detailed documentation
├── terraform/                  # Optional IaC for cloud resources
└── tests/                      # Validation scripts
```

## Dashboards

| Dashboard | Description |
|-----------|-------------|
| [AWS Lambda](dashboards/aws-lambda.json) | Function invocations, errors, duration, concurrency |
| [AWS SQS](dashboards/aws-sqs.json) | Queue depth, message age, throughput |
| [AWS ECS](dashboards/aws-ecs.json) | CPU, memory, task health |
| [GCP Cloud Run](dashboards/gcp-cloudrun.json) | Request counts, latency, container instances |
| [GCP Pub/Sub](dashboards/gcp-pubsub.json) | Message throughput, acknowledgments |
| [Pipeline Overview](dashboards/pipeline-overview.json) | Service topology and data flow |
| [Executive Summary](dashboards/executive-summary.json) | High-level KPIs |
| [System Resources](dashboards/system-resources.json) | Raspberry Pi health |

## Cost Analysis

| Component | One-Time Cost | Monthly Cost |
|-----------|---------------|--------------|
| Raspberry Pi 4 (4GB) | $55-85 | - |
| Power supply + SD card | $20-30 | - |
| Electricity | - | ~$1.50 |
| Grafana Cloud (free tier) | - | $0 |
| AWS CloudWatch API* | - | $0-2 |
| GCP Cloud Monitoring API* | - | $0 |
| **Total** | **~$100** | **~$2/month** |

*API costs depend on resource count. Typical homelab stays within free tiers.

## Security

This project follows security best practices:

- **Least privilege**: IAM policies grant only read access to monitoring data
- **No credentials in git**: All secrets stored in `.env` file (gitignored)
- **Outbound-only**: Raspberry Pi only makes outbound HTTPS connections
- **Minimal attack surface**: No inbound ports required

See [docs/SECURITY.md](docs/SECURITY.md) for detailed security information.

## Useful Commands

```bash
# View container status
docker-compose ps

# View logs
docker-compose logs -f [service-name]

# Restart the stack
docker-compose restart

# Stop the stack
docker-compose down

# Update images
./scripts/update.sh

# Check system health
./scripts/monitor-health.sh

# Backup configuration
./scripts/backup.sh
```

## Troubleshooting

### No metrics in Grafana Cloud

1. Check vmagent logs: `docker-compose logs vmagent`
2. Verify remote write URL and credentials in `.env`
3. Run `./scripts/test-remote-write.sh`

### AWS metrics not appearing

1. Verify IAM credentials: `./scripts/test-aws-connection.sh`
2. Check YACE logs: `docker-compose logs yace`
3. Confirm resources have required tags for discovery

### GCP metrics not appearing

1. Verify service account: `./scripts/test-gcp-connection.sh`
2. Check Stackdriver exporter logs: `docker-compose logs stackdriver-exporter`
3. Ensure Cloud Monitoring API is enabled

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions.

## Documentation

- [Raspberry Pi Setup](docs/SETUP-RASPBERRY-PI.md) - Hardware and OS configuration
- [Grafana Cloud Setup](docs/SETUP-GRAFANA-CLOUD.md) - Account and API key setup
- [AWS Connector Setup](docs/SETUP-AWS-CONNECTOR.md) - IAM user creation
- [GCP Connector Setup](docs/SETUP-GCP-CONNECTOR.md) - Service account creation
- [Architecture Details](ARCHITECTURE.md) - System design and data flow
- [Security Guide](docs/SECURITY.md) - Security best practices
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [VictoriaMetrics](https://victoriametrics.com/) for vmagent
- [YACE](https://github.com/nerdswords/yet-another-cloudwatch-exporter) for CloudWatch exporter
- [Prometheus Community](https://github.com/prometheus-community) for Stackdriver exporter
- [Grafana Labs](https://grafana.com/) for Grafana Cloud
