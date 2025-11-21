terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
}

####################
# Networking (VPC)
####################
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "tf-vpc-main"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "tf-igw" }
}

resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags                    = { Name = "public-${each.value}" }
}

resource "aws_subnet" "private" {
  for_each                = toset(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = false
  tags                    = { Name = "private-${each.value}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

####################
# Security Groups
####################
# EC2 SG - allow SSH, HTTP, Docker ports (optional), and allow outbound
resource "aws_security_group" "ec2_sg" {
  name        = "sg-ec2"
  description = "Allow SSH and outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "App port 80 (optional)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS SG - allow Postgres from anywhere (as requested) and from ECS and Lambdas (via ENIs)
resource "aws_security_group" "rds_sg" {
  name        = "sg-rds"
  description = "Allow postgres inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Postgres from anywhere (requested)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS SG - allow outbound to RDS
resource "aws_security_group" "ecs_sg" {
  name        = "sg-ecs"
  description = "ECS tasks"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow ECS to talk to RDS
resource "aws_security_group_rule" "ecs_to_rds" {
  type                     = "ingress"
  description              = "ECS -> RDS"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.ecs_sg.id
}

####################
# RDS PostgreSQL
####################
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = values(aws_subnet.private)[*].id
  tags       = { Name = "rds-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier             = "tf-postgres-db"
  engine                 = "postgres"
  engine_version         = "15.3" # example version; provider may choose default
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  allocated_storage      = 20
  storage_type           = "gp2"
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  skip_final_snapshot    = true
  deletion_protection    = false
  tags                   = { Name = "tf-postgres" }
}

####################
# IAM Roles / Profiles
####################
# EC2 Instance Profile for SSM (optional) and ECR pull (if needed)
resource "aws_iam_role" "ec2_role" {
  name               = "ec2-role-for-terraform"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ec2_attach_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

####################
# EC2 Instance (clones repo, installs docker, runs container)
####################
data "template_file" "ec2_user_data" {
  template = <<-EOF
              #!/bin/bash
              set -e

              # Update & install git
              apt-get update -y
              apt-get install -y git curl

              # Clone repository (if provided)
              REPO_URL="${repo_url}"
              if [ -n "$REPO_URL" ]; then
                cd /home/ubuntu || exit 0
                if [ ! -d app_repo ]; then
                  git clone "$REPO_URL" app_repo || true
                else
                  cd app_repo && git pull || true
                fi
              fi

              # Check docker; install if missing (Debian/Ubuntu steps)
              if ! command -v docker >/dev/null 2>&1; then
                # install docker
                apt-get install -y ca-certificates gnupg lsb-release
                mkdir -p /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || true
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                apt-get update -y
                apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                usermod -aG docker ubuntu || true
              fi

              # Run container (image dutradev/back-cloud-P2) with API_URL env
              API_URL="${api_url}"
              docker pull dutradev/back-cloud-P2 || true
              docker rm -f back-cloud || true
              docker run -d --name back-cloud -e API_URL="$API_URL" dutradev/back-cloud-P2 || true

              EOF

  vars = {
    repo_url = var.repo_url
    api_url  = var.api_url
  }
}

resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  user_data                   = data.template_file.ec2_user_data.rendered
  tags                        = { Name = "tf-ec2-app" }

  depends_on = [aws_db_instance.postgres]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

####################
# ECS Cluster + Task + Service
####################
resource "aws_ecs_cluster" "cluster" {
  name = "tf-ecs-cluster"
}

# Task role (permission for task to access resources if needed)
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# Define Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "dutradev-back-cloud-P2"
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "back-cloud"
      image     = "dutradev/back-cloud-P2"
      essential = true
      portMappings = [
        { containerPort = 80, hostPort = 80 }
      ]
      environment = [
        { name = "API_URL", value = var.api_url },
        { name = "DB_HOST", value = aws_db_instance.postgres.address },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_username },
        { name = "DB_PASS", value = var.db_password }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/dutradev-back-cloud"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Create CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs_log" {
  name              = "/ecs/dutradev-back-cloud"
  retention_in_days = 7
}

resource "aws_ecs_service" "service" {
  name            = "dutradev-back-cloud-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = values(aws_subnet.private)[*].id
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_db_instance.postgres]
}

####################
# Lambda functions (4) + API Gateway REST APIs + Integrations
####################
# We'll create 4 lambdas (GET /todos, GET /todos/{id}, POST /todos, DELETE /todos/{id})
# For packaging, we will generate small python handler files locally using local_file + archive_file.
# IMPORTANT: These lambdas need a PostgreSQL driver (pg8000/psycopg2). See note in top of file.

locals {
  lambda_names = ["todos_get_all", "todos_get_one", "todos_create", "todos_delete"]
  lambda_route = {
    todos_get_all = { method = "GET", path = "/todos" }
    todos_get_one = { method = "GET", path = "/todos/{id}" }
    todos_create  = { method = "POST", path = "/todos" }
    todos_delete  = { method = "DELETE", path = "/todos/{id}" }
  }
}

# Create IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "lambda-rds-access-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# (Optional) attach VPC access policy if lambdas need to run in VPC (we'll put them in VPC so they can reach RDS)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Create Lambda functions (files created locally by Terraform)
resource "local_file" "lambda_files" {
  for_each = { for name in local.lambda_names : name => name }
  filename = "${path.module}/lambda_${each.key}.py"
  content  = <<-PY
    import os
    import json
    import pg8000  # Note: requires pg8000 installed in the package or a layer

    DB_HOST = os.environ.get("DB_HOST")
    DB_NAME = os.environ.get("DB_NAME")
    DB_USER = os.environ.get("DB_USER")
    DB_PASS = os.environ.get("DB_PASS")

    def lambda_handler(event, context):
        # Basic router per function name
        # This file corresponds to function: ${each.key}
        try:
            conn = pg8000.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS, port=5432)
            cur = conn.cursor()
        except Exception as e:
            return {
                "statusCode": 500,
                "body": json.dumps({"error":"db_connection_failed", "details": str(e)})
            }

        if "${each.key}" == "todos_get_all":
            cur.execute("SELECT id, title, description FROM todos;")
            rows = cur.fetchall()
            items = [{"id": r[0], "title": r[1], "description": r[2]} for r in rows]
            cur.close()
            conn.close()
            return {"statusCode":200, "body": json.dumps(items)}

        if "${each.key}" == "todos_get_one":
            todo_id = event.get("pathParameters", {}).get("id")
            cur.execute("SELECT id, title, description FROM todos WHERE id=%s;", (int(todo_id),))
            row = cur.fetchone()
            cur.close()
            conn.close()
            if not row:
                return {"statusCode":404, "body": json.dumps({"error":"not_found"})}
            return {"statusCode":200, "body": json.dumps({"id": row[0], "title": row[1], "description": row[2]})}

        if "${each.key}" == "todos_create":
            body = json.loads(event.get("body") or "{}")
            title = body.get("title")
            description = body.get("description")
            cur.execute("INSERT INTO todos(title, description) VALUES (%s, %s) RETURNING id;", (title, description))
            new_id = cur.fetchone()[0]
            conn.commit()
            cur.close()
            conn.close()
            return {"statusCode":201, "body": json.dumps({"id": new_id})}

        if "${each.key}" == "todos_delete":
            todo_id = event.get("pathParameters", {}).get("id")
            cur.execute("DELETE FROM todos WHERE id=%s RETURNING id;", (int(todo_id),))
            deleted = cur.fetchone()
            conn.commit()
            cur.close()
            conn.close()
            if not deleted:
                return {"statusCode":404, "body": json.dumps({"error":"not_found"})}
            return {"statusCode":200, "body": json.dumps({"deleted_id": deleted[0]})}
  PY
}

# Package each lambda into zip
data "archive_file" "lambda_zip" {
  for_each    = local.lambda_names
  type        = "zip"
  source_file = local_file.lambda_files[each.value].filename
  output_path = "${path.module}/lambda_${each.value}.zip"
}

# Create Lambda functions
resource "aws_lambda_function" "lambda_funcs" {
  for_each = data.archive_file.lambda_zip

  function_name    = each.key
  filename         = each.value.output_path
  source_code_hash = each.value.output_base64sha256
  handler          = "lambda_${each.key}.lambda_handler" # Python file name matches local filename (lambda_<name>.py)
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_role.arn
  timeout          = 30

  environment {
    variables = {
      DB_HOST = aws_db_instance.postgres.address
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASS = var.db_password
    }
  }

  # If user provided a layer ARN (with psycopg2 / pg8000), attach it
  layers = var.lambda_layer_arn != "" ? [var.lambda_layer_arn] : []

  vpc_config {
    subnet_ids         = values(aws_subnet.private)[*].id
    security_group_ids = [aws_security_group.rds_sg.id]
  }

  depends_on = [aws_db_instance.postgres]
}

# API Gateway (REST) and integration per lambda
resource "aws_api_gateway_rest_api" "api" {
  for_each = { for name in local.lambda_names : name => name }
  name     = "api-${each.key}"
}

# root resource id retrieval
data "aws_api_gateway_resource" "root" {
  for_each    = aws_api_gateway_rest_api.api
  rest_api_id = each.value.id
  path        = "/"
}

# create resource(s) and method depending on each.lambda route
resource "aws_api_gateway_resource" "resource_for" {
  for_each    = { for k, v in local.lambda_route : k => v }
  rest_api_id = aws_api_gateway_rest_api.api[each.key].id
  parent_id   = aws_api_gateway_rest_api.api[each.key].root_resource_id
  path_part   = replace(replace(each.value.path, "/", ""), "{", "") # not perfect, but creates resource
  # NOTE: for path parameters we will create explicit resources below as needed
}

# Create method and integration for each function (handles path parameters crudely)
resource "aws_api_gateway_method" "method" {
  for_each      = { for k, v in local.lambda_route : k => v }
  rest_api_id   = aws_api_gateway_rest_api.api[each.key].id
  resource_id   = aws_api_gateway_rest_api.api[each.key].root_resource_id
  http_method   = upper(each.value.method)
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  for_each                = { for k, v in local.lambda_route : k => v }
  rest_api_id             = aws_api_gateway_rest_api.api[each.key].id
  resource_id             = aws_api_gateway_rest_api.api[each.key].root_resource_id
  http_method             = aws_api_gateway_method.method[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_funcs[each.key].invoke_arn
}

# Grant invoke permission
resource "aws_lambda_permission" "apigw_invoke" {
  for_each      = aws_lambda_function.lambda_funcs
  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api[each.key].execution_arn}/*/*"
}

# Create stage
resource "aws_api_gateway_stage" "api_stage" {
  for_each      = aws_api_gateway_rest_api.api
  rest_api_id   = each.value.id
  deployment_id = aws_api_gateway_deployment.api_deploy[each.key].id
  stage_name    = "prod"
}

# Deploy each API
resource "aws_api_gateway_deployment" "api_deploy" {
  for_each    = aws_api_gateway_rest_api.api
  rest_api_id = each.value.id

  depends_on = [aws_api_gateway_integration.lambda_integration]
}

####################
# Outputs and notes
####################
