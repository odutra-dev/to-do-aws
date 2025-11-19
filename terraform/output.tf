/*
-------------------------
Outputs
-------------------------
*/
/* output "api_invoke_url" {
  description = "Invoke URL for the API Gateway"
  value       = aws_api_gateway_deployment.deployment.invoke_url
}
 */
output "rds_endpoint" {
  description = "RDS endpoint (host)"
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.mysql.port
}

output "lambda_list_arn" {
  description = "ARN of list todos lambda"
  value       = aws_lambda_function.list_todos.arn
}

output "lambda_get_arn" {
  description = "ARN of get todo lambda"
  value       = aws_lambda_function.get_todo.arn
}

output "lambda_delete_arn" {
  description = "ARN of delete todo lambda"
  value       = aws_lambda_function.delete_todo.arn
}
