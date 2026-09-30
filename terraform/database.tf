resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&()*+,-.:;<=>?@[]^_{|}~"
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnets"
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.project_name}-postgres"
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp3"
  db_name                 = var.db_name
  username                = var.db_username
  password                = random_password.db.result
  port                    = 5432
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [aws_security_group.database.id]
  publicly_accessible     = false
  multi_az                = false
  storage_encrypted       = true
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true

  tags = {
    Name = "${var.project_name}-postgres"
  }
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}/database"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-database-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.postgres.address
    port     = "5432"
    dbname   = var.db_name
  })
}
