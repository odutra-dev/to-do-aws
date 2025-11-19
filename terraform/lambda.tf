/*
-------------------------
Lambda code packaging (data "archive_file")
We create three small Node.js handler files via content strings.
In real use replace these with full packages that include 'mysql' and proper DB access.
-------------------------
*/
data "archive_file" "lambda_list_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_list.zip"

  source {
    content  = <<-EOF
      // index.js - GET /todos
      exports.handler = async (event) => {
        // Placeholder example: return static list
        // Replace with real DB logic:
        // const mysql = require('mysql2/promise');
        // const conn = await mysql.createConnection({host: process.env.DB_HOST, user: process.env.DB_USER, password: process.env.DB_PASS, database: process.env.DB_NAME});
        // const [rows] = await conn.execute('SELECT * FROM todos');
        const todos = [
          { id: 1, title: "Exemplo 1", description: "Exemplo 1" },
          { id: 2, title: "Exemplo 2", description: "Exemplo 2" },
        ];
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(todos)
        };
      };
    EOF
    filename = "index.js"
  }
}

data "archive_file" "lambda_get_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_get.zip"

  source {
    content  = <<-EOF
      // index.js - GET /todos/{id}
      exports.handler = async (event) => {
        const id = event.pathParameters && event.pathParameters.id;
        // Replace with DB lookup code
        const todo = { id: id, title: "Exemplo " + id };
        if (!id) {
          return { statusCode: 400, body: "Missing id" };
        }
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(todo)
        };
      };
    EOF
    filename = "index.js"
  }
}

data "archive_file" "lambda_delete_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_delete.zip"

  source {
    content  = <<-EOF
      // index.js - DELETE /todos/{id}
      exports.handler = async (event) => {
        const id = event.pathParameters && event.pathParameters.id;
        if (!id) return { statusCode: 400, body: "Missing id" };
        // Replace with DB deletion code:
        // await conn.execute('DELETE FROM todos WHERE id=?', [id]);
        return {
          statusCode: 200,
          body: JSON.stringify({ message: `Deleted $${id}` })
        };
      };
    EOF
    filename = "index.js"
  }
}

/*
-------------------------
Lambda functions (3)
- Each function uses the VPC config to run inside private subnets so it can reach RDS.
- Environment variables provided for DB connection (placeholders)
-------------------------
*/
resource "aws_lambda_function" "list_todos" {
  function_name    = "${var.project_name}-list-todos"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_list_zip.output_path
  source_code_hash = data.archive_file.lambda_list_zip.output_base64sha256
  timeout          = var.lambda_timeout

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST = aws_db_instance.mysql.address
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASS = var.db_password
    }
  }

  tags = { Name = "${var.project_name}-list-todos" }
}

resource "aws_lambda_function" "get_todo" {
  function_name    = "${var.project_name}-get-todo"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_get_zip.output_path
  source_code_hash = data.archive_file.lambda_get_zip.output_base64sha256
  timeout          = var.lambda_timeout

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST = aws_db_instance.mysql.address
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASS = var.db_password
    }
  }

  tags = { Name = "${var.project_name}-get-todo" }
}

resource "aws_lambda_function" "delete_todo" {
  function_name    = "${var.project_name}-delete-todo"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_delete_zip.output_path
  source_code_hash = data.archive_file.lambda_delete_zip.output_base64sha256
  timeout          = var.lambda_timeout

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST = aws_db_instance.mysql.address
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASS = var.db_password
    }
  }

  tags = { Name = "${var.project_name}-delete-todo" }
}
