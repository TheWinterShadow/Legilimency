# AWS Connector Setup Guide

This guide walks you through creating an IAM user with minimal permissions for CloudWatch monitoring.

## Overview

The AWS connector (YACE) needs read-only access to:

- CloudWatch metrics (for actual metric data)
- AWS service APIs (for resource discovery)
- Resource tags (for filtering and labeling)

## Security Principles

- **Read-only access**: No ability to modify or delete anything
- **Least privilege**: Only permissions needed for monitoring
- **No console access**: Programmatic access only
- **Credential rotation**: Rotate keys periodically

## Option A: AWS Console Setup

### Step 1: Create IAM Policy

1. Sign in to AWS Console: https://console.aws.amazon.com/iam/
2. Navigate to **Policies** → **Create policy**
3. Click **JSON** tab
4. Paste the policy from `cloud-connectors/aws/iam-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchReadOnly",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ResourceTagDiscovery",
      "Effect": "Allow",
      "Action": [
        "tag:GetResources"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LambdaDiscovery",
      "Effect": "Allow",
      "Action": [
        "lambda:ListFunctions",
        "lambda:ListTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SQSDiscovery",
      "Effect": "Allow",
      "Action": [
        "sqs:ListQueues",
        "sqs:GetQueueAttributes",
        "sqs:ListQueueTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSServiceDiscovery",
      "Effect": "Allow",
      "Action": [
        "ecs:ListClusters",
        "ecs:ListServices",
        "ecs:DescribeServices",
        "ecs:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "APIGatewayDiscovery",
      "Effect": "Allow",
      "Action": [
        "apigateway:GET"
      ],
      "Resource": "*"
    }
  ]
}
```

5. Click **Next**
6. Name: `MonitoringReadOnlyPolicy`
7. Description: `Read-only access for external monitoring system`
8. Click **Create policy**

### Step 2: Create IAM User

1. Navigate to **Users** → **Create user**
2. User name: `monitoring-readonly`
3. Leave "Provide user access to the AWS Management Console" **unchecked**
4. Click **Next**
5. Select **Attach policies directly**
6. Search for and select `MonitoringReadOnlyPolicy`
7. Click **Next**
8. Click **Create user**

### Step 3: Create Access Key

1. Click on the newly created user
2. Go to **Security credentials** tab
3. Under "Access keys", click **Create access key**
4. Select **Application running outside AWS**
5. Click **Next**
6. Description: `Raspberry Pi monitoring`
7. Click **Create access key**
8. **Download the CSV file** or copy both keys immediately
9. Click **Done**

⚠️ **Important**: The secret access key is only shown once. If you lose it, you must create a new access key.

## Option B: AWS CLI Setup

### Prerequisites

```bash
# Install AWS CLI
sudo apt install awscli

# Configure with admin credentials (temporarily)
aws configure
```

### Create Policy and User

```bash
# Create the policy
aws iam create-policy \
  --policy-name MonitoringReadOnlyPolicy \
  --policy-document file://cloud-connectors/aws/iam-policy.json

# Note the policy ARN from the output
# Example: arn:aws:iam::123456789012:policy/MonitoringReadOnlyPolicy

# Create the user
aws iam create-user --user-name monitoring-readonly

# Attach the policy (replace with your account ID)
aws iam attach-user-policy \
  --user-name monitoring-readonly \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/MonitoringReadOnlyPolicy

# Create access key
aws iam create-access-key --user-name monitoring-readonly
```

The output will show:

```json
{
  "AccessKey": {
    "UserName": "monitoring-readonly",
    "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
    "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "Status": "Active"
  }
}
```

## Option C: Terraform Setup

See `terraform/aws/iam.tf` for Infrastructure as Code option.

```bash
cd terraform/aws
terraform init
terraform apply
```

## Configure Environment Variables

Add to your `.env` file:

```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=us-east-1
AWS_REGIONS_TO_MONITOR=us-east-1,us-west-2
```

## Verify Credentials

### Test with AWS CLI

```bash
# Set credentials
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_REGION=us-east-1

# Verify identity
aws sts get-caller-identity

# Should output something like:
# {
#   "UserId": "AIDAXXXXXXXXXXXXXXXX",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/monitoring-readonly"
# }

# Test CloudWatch access
aws cloudwatch list-metrics --namespace AWS/Lambda | head -20
```

### Test with Script

```bash
./scripts/test-aws-connection.sh
```

## Tag Your Resources

YACE discovers resources using tags. Add these tags to resources you want to monitor:

| Tag Key | Example Value | Purpose |
|---------|---------------|---------|
| `Environment` | `production` | Filter by environment |
| `Project` | `myapp` | Group related resources |
| `Name` | `order-processor` | Human-readable name |

### Example: Tag Lambda Functions

```bash
aws lambda tag-resource \
  --resource arn:aws:lambda:us-east-1:123456789012:function:my-function \
  --tags Environment=production,Project=myapp
```

### Example: Tag SQS Queues

```bash
aws sqs tag-queue \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/my-queue \
  --tags Environment=production,Project=myapp
```

## Multi-Region Monitoring

To monitor multiple AWS regions, update `AWS_REGIONS_TO_MONITOR`:

```bash
AWS_REGIONS_TO_MONITOR=us-east-1,us-west-2,eu-west-1
```

Each region will have its own CloudWatch API calls, so costs scale with number of regions.

## CloudWatch API Costs

### Pricing

- GetMetricData: $0.01 per 1,000 metrics requested
- ListMetrics: Free

### Estimated Monthly Cost

| Resources | Scrape Interval | Monthly Cost |
|-----------|-----------------|--------------|
| 10 Lambda functions | 5 min | ~$0.30 |
| 5 SQS queues | 5 min | ~$0.15 |
| 3 ECS services | 5 min | ~$0.10 |
| **Total** | | **~$0.55** |

### Reducing Costs

1. Increase scrape interval (300s → 600s)
2. Reduce number of metrics per service in `yace-config.yml`
3. Use tag filters to monitor only critical resources

## Troubleshooting

### "Access Denied" Errors

1. Verify the IAM policy is attached:

   ```bash
   aws iam list-attached-user-policies --user-name monitoring-readonly
   ```

2. Check the policy has all required permissions

3. Verify credentials are correct:

   ```bash
   aws sts get-caller-identity
   ```

### "No Metrics Found"

1. Ensure resources exist in the specified regions
2. Check resources have the expected tags
3. Verify CloudWatch has metrics (some services only report when active):

   ```bash
   aws cloudwatch list-metrics --namespace AWS/Lambda
   ```

### YACE Container Errors

View YACE logs:

```bash
docker-compose logs yace
```

Common issues:

- Invalid AWS credentials
- Missing permissions
- Network connectivity issues

## Security Best Practices

### Rotate Access Keys

Rotate keys every 90 days:

1. Create new access key
2. Update `.env` with new credentials
3. Restart containers: `docker-compose restart`
4. Verify metrics still flowing
5. Delete old access key

### Monitor API Usage

Set up CloudWatch billing alerts:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "CloudWatch-API-Spend" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

### Restrict IP Access (Optional)

Add IP condition to IAM policy if your Pi has a static IP:

```json
{
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": "YOUR.PUBLIC.IP.ADDRESS/32"
    }
  }
}
```

## Next Steps

1. [Set up GCP connector](SETUP-GCP-CONNECTOR.md)
2. Run the setup script: `./scripts/setup.sh`
3. Verify AWS metrics appear in Grafana
