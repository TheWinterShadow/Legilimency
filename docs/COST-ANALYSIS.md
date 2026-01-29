# Cost Analysis

A detailed breakdown of costs for running the multi-cloud monitoring stack.

## Summary

| Category | One-Time | Monthly | Annual |
|----------|----------|---------|--------|
| Hardware | $85-115 | - | - |
| Electricity | - | $1.50 | $18 |
| Grafana Cloud | - | $0 | $0 |
| AWS CloudWatch API | - | $0-2 | $0-24 |
| GCP Monitoring API | - | $0 | $0 |
| **Total** | **$85-115** | **$1.50-3.50** | **$18-42** |

## Hardware Costs (One-Time)

### Raspberry Pi Kit

| Component | Price Range | Recommended |
|-----------|-------------|-------------|
| Raspberry Pi 4 (4GB) | $55-75 | Required |
| Raspberry Pi 4 (8GB) | $75-95 | Optional upgrade |
| Official Power Supply | $8-15 | Required |
| microSD Card (32GB A2) | $10-15 | Required |
| Case with Heatsink/Fan | $10-20 | Recommended |
| Ethernet Cable | $5-10 | Recommended |

**Total: $88-130** for a complete setup

### Budget Option

| Component | Price |
|-----------|-------|
| Raspberry Pi 4 (2GB) | $35-45 |
| Generic Power Supply | $8 |
| Basic microSD (16GB) | $8 |
| Passive Heatsink Case | $8 |
| **Total** | **~$60** |

⚠️ The 2GB model will be memory-constrained. Consider reducing container memory limits.

## Electricity Costs

### Power Consumption

| State | Power Draw | Notes |
|-------|------------|-------|
| Idle | 2.7W | No containers running |
| Light Load | 4-5W | Normal monitoring |
| Full Load | 6-8W | All containers active |
| **Average** | **5W** | Typical 24/7 operation |

### Monthly Cost Calculation

```
Power (kWh/month) = 5W × 24h × 30 days / 1000 = 3.6 kWh
Cost = 3.6 kWh × $0.12/kWh = $0.43/month
```

With efficiency losses and occasional spikes:

- **Conservative estimate: $1.50/month**
- **Annual: ~$18**

### Comparison to Cloud Alternatives

| Option | Monthly Cost |
|--------|--------------|
| Raspberry Pi | $1.50 |
| AWS t3.micro (free tier, 1 year) | $0 → $8.50 |
| AWS t3.small | $17 |
| GCP e2-micro (free tier, always free) | $0 |
| GCP e2-small | $13 |
| DigitalOcean Basic Droplet | $6 |

The Raspberry Pi approach eliminates ongoing compute costs while providing comparable functionality.

## Grafana Cloud Costs

### Free Tier Includes

| Resource | Limit | Typical Usage |
|----------|-------|---------------|
| Active metric series | 10,000 | 2,000-5,000 |
| Metrics retention | 14 days | N/A |
| Grafana users | 3 | 1-2 |
| Dashboards | Unlimited | 8-10 |
| Alerting | Included | 10-20 rules |
| Log retention | 50GB | Not used |

### Monitoring Series Usage

Estimate your series count:

| Source | Series per Resource | Example Resources | Total Series |
|--------|---------------------|-------------------|--------------|
| Lambda (10 functions) | 20 metrics/function | 10 | 200 |
| SQS (5 queues) | 10 metrics/queue | 5 | 50 |
| ECS (3 services) | 15 metrics/service | 3 | 45 |
| Cloud Run (5 services) | 20 metrics/service | 5 | 100 |
| Node Exporter | ~100 metrics | 1 | 100 |
| cAdvisor | ~50 metrics/container | 5 | 250 |
| vmagent self-monitoring | ~30 metrics | 1 | 30 |
| **Total** | | | **~775** |

With labels and cardinality, actual might be 2-3x higher: **~1,500-2,500 series**

Well within the 10,000 free tier limit.

### Paid Tier Pricing

If you exceed free tier limits:

| Plan | Series Limit | Price/month |
|------|--------------|-------------|
| Free | 10,000 | $0 |
| Pro | 10,000+ | $0.008/active series |

Example: 15,000 series = $40/month ($120/month base + overage)

### Staying Within Free Tier

1. **Metric relabeling**: Drop unnecessary metrics
2. **Appropriate intervals**: 5-minute for CloudWatch (standard resolution)
3. **Tag-based discovery**: Only monitor tagged resources
4. **Aggregation**: Use recording rules if needed

## AWS CloudWatch API Costs

### API Pricing

| API Call | Price |
|----------|-------|
| GetMetricData | $0.01 per 1,000 metrics |
| ListMetrics | Free |
| GetMetricStatistics | $0.01 per 1,000 requests |

### Usage Calculation

**Per scrape (5-minute interval):**

- Lambda: 10 functions × 7 metrics = 70 metrics
- SQS: 5 queues × 6 metrics = 30 metrics
- ECS: 3 services × 4 metrics = 12 metrics
- API Gateway: 2 APIs × 4 metrics = 8 metrics
- **Total per scrape: 120 metrics**

**Daily:**

```
Scrapes per day = 24 hours × 12 (5-min intervals) = 288
Metrics per day = 288 × 120 = 34,560 metrics
```

**Monthly:**

```
Metrics per month = 34,560 × 30 = 1,036,800 metrics
Cost = 1,036,800 / 1,000 × $0.01 = $10.37
```

### Cost Reduction Strategies

| Strategy | Savings |
|----------|---------|
| Reduce metrics (drop unused) | 20-40% |
| Increase interval (5min → 10min) | 50% |
| Reduce regions monitored | Variable |
| Use tag filters | Variable |

**Realistic monthly cost: $0-5** with optimizations

### Free Tier Considerations

AWS Free Tier includes:

- 1 million API requests per month (various services)
- Some CloudWatch metrics are free (basic EC2, etc.)

Small monitoring setups often stay within free tier.

## GCP Cloud Monitoring API Costs

### API Pricing

| Operation | Price |
|-----------|-------|
| Monitoring API reads | Free (within quota) |
| Writing custom metrics | $0.10 per 1,000 time series |

### Quotas

- 6,000 read requests per minute per project
- Typically no cost for reading metrics

### Expected Cost

**$0/month** for typical monitoring setups

GCP's free tier is generous for monitoring API reads.

## Total Cost of Ownership

### First Year

| Item | Cost |
|------|------|
| Hardware (one-time) | $100 |
| Electricity (12 months) | $18 |
| AWS API calls (12 months) | $24 |
| Grafana Cloud | $0 |
| **Total Year 1** | **$142** |

### Subsequent Years

| Item | Cost |
|------|------|
| Electricity | $18 |
| AWS API calls | $24 |
| Grafana Cloud | $0 |
| **Total per year** | **$42** |

### Comparison: 3-Year TCO

| Solution | Year 1 | Year 2 | Year 3 | Total |
|----------|--------|--------|--------|-------|
| **Raspberry Pi** | $142 | $42 | $42 | **$226** |
| AWS CloudWatch + EC2 | $300 | $300 | $300 | $900 |
| Datadog Pro (5 hosts) | $276 | $276 | $276 | $828 |
| New Relic | $0* | $0* | $0* | $0* |
| Self-hosted Prometheus (EC2) | $150 | $102 | $102 | $354 |

*New Relic has a free tier but limited retention and features

## Scaling Costs

### Adding More Resources to Monitor

| Scenario | Additional Monthly Cost |
|----------|------------------------|
| +10 Lambda functions | +$0.50-1 |
| +5 SQS queues | +$0.25-0.50 |
| +1 AWS region | +$0.50-2 |
| +1 GCP project | +$0 (service account) |

### Multiple Raspberry Pis

| Setup | Additional Cost |
|-------|-----------------|
| Second Pi (different location) | +$100 one-time, +$1.50/mo |
| Third Pi | +$100 one-time, +$1.50/mo |

Grafana Cloud handles multiple sources easily within free tier.

### Upgrading to Paid Grafana Cloud

When to consider:

- Exceeding 10,000 series
- Need longer retention (>14 days)
- Need more users (>3)
- Need enterprise features

Starting price: ~$50/month for Pro tier

## Cost Optimization Tips

### Hardware

1. Buy during sales (Prime Day, Black Friday)
2. Consider used Raspberry Pi 4s
3. Use SSD instead of SD card for longevity (extra $20)

### Operations

1. Monitor your Grafana Cloud series usage monthly
2. Review and drop unused metrics quarterly
3. Increase CloudWatch scrape interval if 5min resolution not needed
4. Use AWS Savings Plans if running other AWS resources

### Electricity

1. Use efficient power supply
2. Disable unused peripherals (Bluetooth, WiFi if using Ethernet)
3. Consider solar + battery for off-grid setups

## ROI Calculation

### Time Saved

| Task | Before (Manual) | After (Automated) |
|------|-----------------|-------------------|
| Check Lambda errors | 15 min/day | 0 (alerts) |
| Review SQS backlogs | 10 min/day | 0 (dashboard) |
| Check ECS health | 10 min/day | 0 (dashboard) |
| Investigate issues | Variable | 50% faster (metrics) |

**Estimated time saved: 30+ min/day**

### Value

If your time is worth $50/hour:

- 30 min/day × 20 workdays × $50/hour / 2 = $250/month
- Annual value: $3,000

**ROI: >10x** compared to $226 3-year TCO
