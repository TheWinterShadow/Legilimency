# AWS Terraform Configuration for Monitoring IAM User
# Creates a read-only IAM user for CloudWatch monitoring

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "raspberry-pi-monitoring"
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region for the IAM user"
  type        = string
  default     = "us-east-1"
}

variable "user_name" {
  description = "Name of the IAM user for monitoring"
  type        = string
  default     = "monitoring-readonly"
}

# IAM Policy for CloudWatch monitoring
resource "aws_iam_policy" "monitoring_readonly" {
  name        = "MonitoringReadOnlyPolicy"
  description = "Read-only access for external monitoring system (Raspberry Pi + Grafana Cloud)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchReadOnly"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "ResourceTagDiscovery"
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaDiscovery"
        Effect = "Allow"
        Action = [
          "lambda:ListFunctions",
          "lambda:ListTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "SQSDiscovery"
        Effect = "Allow"
        Action = [
          "sqs:ListQueues",
          "sqs:GetQueueAttributes",
          "sqs:ListQueueTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSServiceDiscovery"
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "APIGatewayDiscovery"
        Effect = "Allow"
        Action = [
          "apigateway:GET"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "MonitoringReadOnlyPolicy"
  }
}

# IAM User for monitoring
resource "aws_iam_user" "monitoring" {
  name = var.user_name

  tags = {
    Name        = var.user_name
    Description = "Read-only user for external monitoring"
  }
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "monitoring" {
  user       = aws_iam_user.monitoring.name
  policy_arn = aws_iam_policy.monitoring_readonly.arn
}

# Create access key for the user
resource "aws_iam_access_key" "monitoring" {
  user = aws_iam_user.monitoring.name
}
