output "vpc_id" {
  value = aws_vpc.main.id
}

output "ec2_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "rds_port" {
  value = aws_db_instance.postgres.port
}

output "ecs_cluster" {
  value = aws_ecs_cluster.cluster.id
}

output "ecs_service" {
  value = aws_ecs_service.service.name
}

output "api_gateway_urls" {
  value = { for k, v in aws_api_gateway_rest_api.api : k => v.execution_arn }
}

output "lambda_names" {
  value = [for f in aws_lambda_function.lambda_funcs : f.function_name]
}
