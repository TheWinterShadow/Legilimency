# Terraform Infrastructure as Code

This directory contains Terraform configurations for setting up cloud provider credentials.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0.0
- AWS CLI configured with admin credentials (for AWS)
- gcloud CLI configured with admin credentials (for GCP)

## AWS Setup

### 1. Navigate to AWS Directory

```bash
cd terraform/aws
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

### 3. Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

### 4. Get Credentials

```bash
# Access Key ID (shown in output)
terraform output access_key_id

# Secret Access Key
terraform output -raw secret_access_key
```

### 5. Update .env

Add the credentials to your `.env` file in the project root.

## GCP Setup

### 1. Navigate to GCP Directory

```bash
cd terraform/gcp
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project ID
```

### 3. Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

### 4. Verify Key File

The service account key is automatically saved to:

```
configs/gcp-service-account-key.json
```

### 5. Update .env

Add the GCP settings to your `.env` file:

```bash
GCP_PROJECT_ID=your-project-id
GCP_KEY_PATH=./configs/gcp-service-account-key.json
```

## Cleanup

To remove all created resources:

```bash
# AWS
cd terraform/aws
terraform destroy

# GCP
cd terraform/gcp
terraform destroy
```

## State Management

For production use, consider using remote state storage:

### AWS S3 Backend (Example)

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "monitoring/aws/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### GCP Cloud Storage Backend (Example)

```hcl
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "monitoring/gcp"
  }
}
```

## Security Notes

- Never commit `terraform.tfvars` files containing sensitive values
- The `.gitignore` is configured to exclude:
  - `*.tfvars` (except `.example`)
  - `*.tfstate`
  - `*.tfstate.*`
  - `.terraform/`
- The GCP service account key is automatically saved with restricted permissions (0600)

## Credential Rotation

### Rotate AWS Credentials

```bash
cd terraform/aws

# Taint the access key resource
terraform taint aws_iam_access_key.monitoring

# Apply to create new key
terraform apply

# Update .env with new credentials
```

### Rotate GCP Credentials

```bash
cd terraform/gcp

# Taint the key resource
terraform taint google_service_account_key.monitoring
terraform taint local_file.service_account_key

# Apply to create new key
terraform apply

# Key file is automatically updated
```
