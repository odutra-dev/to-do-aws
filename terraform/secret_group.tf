/*
-------------------------
Security Groups
- lambda_sg: used by Lambda functions. Allows egress to RDS on 3306
- rds_sg: allows ingress from lambda_sg to 3306
-------------------------
*/
resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambdas"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project_name}-lambda-sg" }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS MySQL"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.project_name}-rds-sg" }

  ingress {
    description     = "Allow MySQL from lambda SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  // No public access; RDS not publicly accessible
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
