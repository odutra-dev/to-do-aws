/*
-------------------------
RDS Subnet Group + MySQL instance
- private subnets only
-------------------------
*/
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "${var.project_name}-rds-subnet-group" }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_name}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0" // placeholder, change if necessary
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  allocated_storage      = var.db_allocated_storage
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
  multi_az               = false
  apply_immediately      = true

  tags = {
    Name = "${var.project_name}-mysql"
  }
}

/* 
resource "null_resource" "create_todos_table" {
  depends_on = [aws_db_instance.mysql]

  provisioner "local-exec" {
    command = <<EOF
sleep 30
mysql --host=${aws_db_instance.mysql.address} \
      --user=${var.db_username} \
      --password="${var.db_password}" \
      --database=${var.db_name} <<'EOSQL'
CREATE TABLE IF NOT EXISTS todos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT
);
EOSQL
EOF
  }
} */
