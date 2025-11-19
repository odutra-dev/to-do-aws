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

# Variaveis do Banco de Dados

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "todo-stack"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "todosdb"
}

variable "db_username" {
  description = "DB master username (placeholder)"
  type        = string
  default     = "adminuser"
}

variable "db_password" {
  description = "DB master password (placeholder) - change in real deployment"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage (GB)"
  type        = number
  default     = 20
}

# Variaveis do Lambda

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_timeout" {
  description = "Lambda timeout (seconds)"
  type        = number
  default     = 10
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "dev"
}
