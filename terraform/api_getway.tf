###############################################
# API GATEWAY - REST API
###############################################
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api"
  description = "API for todos - integrated with Lambdas"
}

###############################################
# RESOURCES
###############################################

# /todos
resource "aws_api_gateway_resource" "todos" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "todos"
}

# /todos/{id}
resource "aws_api_gateway_resource" "todo_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.todos.id
  path_part   = "{id}"
}


###############################################
# METHODS + INTEGRATIONS
###############################################

########### GET /todos ###########
resource "aws_api_gateway_method" "get_todos" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.todos.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_todos_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.todos.id
  http_method = aws_api_gateway_method.get_todos.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_todos.invoke_arn
}


########### GET /todos/{id} ###########
resource "aws_api_gateway_method" "get_todo" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.todo_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "get_todo_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.todo_id.id
  http_method = aws_api_gateway_method.get_todo.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_todo.invoke_arn
}


########### DELETE /todos/{id} ###########
resource "aws_api_gateway_method" "delete_todo" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.todo_id.id
  http_method   = "DELETE"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "delete_todo_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.todo_id.id
  http_method = aws_api_gateway_method.delete_todo.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.delete_todo.invoke_arn
}


###############################################
# PERMISSÕES PARA O API GATEWAY INVOCAR AS LAMBDAS
###############################################

resource "aws_lambda_permission" "apigw_invoke_list" {
  statement_id  = "AllowAPIGWInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_todos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_get" {
  statement_id  = "AllowAPIGWInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_todo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_delete" {
  statement_id  = "AllowAPIGWInvokeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_todo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}


###############################################
# DEPLOYMENT (REDEPLOY QUANDO A API MUDAR)
###############################################
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  # garante redeploy automático
  triggers = {
    redeployment = sha1(jsonencode({
      resources   = aws_api_gateway_rest_api.api.root_resource_id
      todos       = aws_api_gateway_resource.todos.id
      todos_id    = aws_api_gateway_resource.todo_id.id
      get_todos   = aws_api_gateway_method.get_todos.id
      get_todo    = aws_api_gateway_method.get_todo.id
      delete_todo = aws_api_gateway_method.delete_todo.id
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}


###############################################
# STAGE "dev"
###############################################
resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = "dev"
}

###############################################
# LOGGING + METRICS (OPTIONAL, MAS RECOMENDADO)
###############################################

resource "aws_api_gateway_account" "api_account" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }

  depends_on = [
    aws_api_gateway_account.api_account
  ]
}


###############################################
# OUTPUT DA URL FINAL
###############################################
output "api_url" {
  value = "${aws_api_gateway_rest_api.api.execution_arn}://${aws_api_gateway_stage.dev.stage_name}"
}
