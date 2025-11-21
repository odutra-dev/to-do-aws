variable "access_key" {
  description = "AWS access key"
  type        = string
}

variable "secret_key" {
  description = "AWS secret key"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnets CIDRs (list)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnets CIDRs (list) - used for RDS/ECS"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "key_name" {
  description = "EC2 Key pair name for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "repo_url" {
  description = "Git repository to clone on EC2 (HTTPS URL)"
  type        = string
  default     = "https://github.com/odutra-dev/to-do-aws.git"
}

variable "api_url" {
  description = "API_URL value to pass to container(s) (ex: https://abcd.execute-api.region.amazonaws.com/prod )"
  type        = string
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  type        = string
  description = "Postgres password"
  default     = "postgres"
  sensitive   = true
}

variable "db_name" {
  type    = string
  default = "todosdb"
}

variable "ecs_desired_count" {
  type    = number
  default = 1
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into EC2. Use 0.0.0.0/0 only for testing (NOT RECOMMENDED)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.9"
}

# Optional - specify existing lambda layer S3 (for pg/psycopg2) if you have one
variable "lambda_layer_arn" {
  description = "Optional ARN of a Lambda Layer that provides PostgreSQL driver (psycopg2 / pg8000). If empty, lambda may fail unless you package dependencies."
  type        = string
  default     = ""
}
