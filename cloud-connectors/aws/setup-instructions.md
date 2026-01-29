# AWS Cloud Connector Setup Instructions

This guide walks you through creating an IAM user with minimal read-only permissions for monitoring AWS resources via CloudWatch.

## Prerequisites

- AWS account with admin access (to create IAM users)
- AWS CLI installed (optional, for verification)

## Step 1: Create IAM User

1. Log in to AWS Console: https://console.aws.amazon.com
2. Navigate to **IAM** → **Users** → **Create user**
3. Enter username: `monitoring-readonly`
4. Select: **Provide user access to the AWS Management Console** (optional, for manual verification)
   - Or select: **Access key - Programmatic access** (recommended for automation)
5. Click **Next**

## Step 2: Attach Custom Policy

1. On the **Set permissions** page, select **Attach policies directly**
2. Click **Create policy**
3. Click **JSON** tab
4. Copy the contents of `cloud-connectors/aws/iam-policy.json` and paste into the JSON editor
5. Click **Next**
6. Name the policy: `MonitoringReadOnlyPolicy`
7. Description: `Read-only access to CloudWatch metrics and resource discovery for external monitoring`
8. Click **Create policy**
9. Go back to the user creation page
10. Refresh the policy list
11. Search for and select `MonitoringReadOnlyPolicy`
12. Click **Next**

## Step 3: Review and Create

1. Review the user configuration
2. Click **Create user**
3. **Important**: Save the user ARN for reference (e.g., `arn:aws:iam::123456789012:user/monitoring-readonly`)

## Step 4: Create Access Key

1. Click on the newly created user: `monitoring-readonly`
2. Go to **Security credentials** tab
3. Scroll to **Access keys** section
4. Click **Create access key**
5. Select **Command Line Interface (CLI)** as use case
6. Check the confirmation box
7. Click **Next**
8. Optionally add a description tag
9. Click **Create access key**
10. **CRITICAL**: Copy both:
    - **Access key ID** (e.g., `AKIAIOSFODNN7EXAMPLE`)
    - **Secret access key** (e.g., `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)
11. **Important**: The secret access key is shown only once. Save it securely!
12. Click **Done**

## Step 5: Verify Credentials

### Using AWS CLI

```bash
# Configure AWS CLI with the new credentials
aws configure --profile monitoring
# Enter Access Key ID
# Enter Secret Access Key
# Enter default region (e.g., us-east-1)
# Enter default output format (json)

# Test CloudWatch access
aws cloudwatch list-metrics --namespace AWS/Lambda --profile monitoring

# Test IAM identity
aws sts get-caller-identity --profile monitoring
```

### Using Test Script

```bash
# From the project root directory
./scripts/test-aws-connection.sh
```

Expected output:

```
✓ AWS credentials configured
✓ AWS identity verified: arn:aws:iam::123456789012:user/monitoring-readonly
✓ CloudWatch API accessible
✓ Lambda functions discoverable
```

## Step 6: Add to .env File

1. Open `.env` file (create from `.env.example` if needed)
2. Add the credentials:

```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=us-east-1
AWS_REGIONS_TO_MONITOR=us-east-1,us-west-2
```

3. Save the file
4. **Verify `.env` is in `.gitignore`** (it should be by default)

## Step 7: Test YACE Connection

After starting the Docker stack:

```bash
# Check YACE logs
docker-compose logs yace

# Check YACE metrics endpoint
curl http://localhost:5000/metrics | grep aws_lambda
```

You should see AWS Lambda metrics if you have Lambda functions in the monitored regions.

## Troubleshooting

### "Access Denied" Errors

- Verify the IAM policy is attached to the user
- Check that the policy JSON is valid (no syntax errors)
- Ensure the user has the correct permissions (see `iam-policy.json`)

### No Metrics Appearing

- Verify AWS regions in `AWS_REGIONS_TO_MONITOR` match your resources
- Check that resources have CloudWatch metrics enabled
- Review YACE logs: `docker-compose logs yace`
- Verify CloudWatch API is accessible: `aws cloudwatch list-metrics --namespace AWS/Lambda`

### High API Costs

- YACE scrapes at 5-minute intervals by default (matches CloudWatch granularity)
- Each region adds to API call count
- Monitor CloudWatch API usage in AWS Cost Explorer
- Expected cost: $0-2/month for typical homelab usage

## Security Best Practices

1. **Least Privilege**: This policy grants only read-only access to CloudWatch metrics
2. **No Write Access**: The user cannot modify or delete any AWS resources
3. **Resource Discovery Only**: List permissions are minimal (only what's needed for discovery)
4. **Rotate Keys**: Rotate access keys every 90 days
5. **Monitor Usage**: Set up CloudTrail alerts for unusual API activity
6. **MFA**: Consider enabling MFA for console access (not required for programmatic access)

## Alternative: Using Terraform

If you prefer Infrastructure as Code, see `terraform/aws/iam.tf` for Terraform configuration.

```bash
cd terraform/aws
terraform init
terraform plan
terraform apply
```

The Terraform output will include the access key ID and secret (stored securely in Terraform state).

## Next Steps

- [ ] Test GCP connector setup: `docs/SETUP-GCP-CONNECTOR.md`
- [ ] Configure Grafana Cloud: `docs/SETUP-GRAFANA-CLOUD.md`
- [ ] Start monitoring stack: `./scripts/setup.sh`
