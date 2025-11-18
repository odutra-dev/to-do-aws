variable "access_key" {
  type        = string
  description = "AWS access key"
  sensitive   = true
}

variable "secret_key" {
  type        = string
  description = "AWS secret key"
  sensitive   = true
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}
