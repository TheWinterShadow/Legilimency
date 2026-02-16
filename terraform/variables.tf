variable "secret_token" {
  type      = string
  sensitive = true
  description = "Secret token for webhook authentication (x-vapi-secret header)"
}

variable "region" {
  type    = string
  default = "us-east-1"
  description = "AWS region for resources"
}
