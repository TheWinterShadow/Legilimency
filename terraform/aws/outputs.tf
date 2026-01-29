# Output values for AWS monitoring setup
# IMPORTANT: These outputs contain sensitive values. Handle with care.

output "iam_user_name" {
  description = "Name of the IAM user created for monitoring"
  value       = aws_iam_user.monitoring.name
}

output "iam_user_arn" {
  description = "ARN of the IAM user"
  value       = aws_iam_user.monitoring.arn
}

output "iam_policy_arn" {
  description = "ARN of the monitoring policy"
  value       = aws_iam_policy.monitoring_readonly.arn
}

output "access_key_id" {
  description = "AWS Access Key ID for the monitoring user"
  value       = aws_iam_access_key.monitoring.id
  sensitive   = false # Key ID is not sensitive
}

output "secret_access_key" {
  description = "AWS Secret Access Key for the monitoring user"
  value       = aws_iam_access_key.monitoring.secret
  sensitive   = true # Secret is sensitive - will not be shown in console
}

# Instructions for using the credentials
output "instructions" {
  description = "Instructions for using the credentials"
  value       = <<-EOT

    ========================================
    AWS Monitoring User Created Successfully
    ========================================

    Add these values to your .env file:

    AWS_ACCESS_KEY_ID=${aws_iam_access_key.monitoring.id}
    AWS_SECRET_ACCESS_KEY=<run 'terraform output -raw secret_access_key' to get this value>
    AWS_REGION=${var.aws_region}

    To get the secret access key:
    terraform output -raw secret_access_key

    IMPORTANT: Store these credentials securely!

  EOT
}
